#include "mscore.h"

#if defined _MACOS_
#include <QAudio>
#include <QAudioDeviceInfo>
#include <QAudioFormat>
#include <QAudioInput>
#include <QByteArray>
#include <QIODevice>
#include <QtGlobal>
#include <stdio.h>
#include <string.h>

static QAudioInput *mac_audio_input = NULL;
static QIODevice *mac_audio_input_device = NULL;
static int mac_audio_input_channels = 0;
static int mac_audio_input_sample_bytes = 0;
static int mac_audio_input_sample_bits = 0;
static QAudioFormat::SampleType mac_audio_input_sample_type = QAudioFormat::Unknown;
static QAudioFormat::Endian mac_audio_input_byte_order = QAudioFormat::LittleEndian;

static void hv_mac_release_input()
{
    if (mac_audio_input)
    {
        mac_audio_input->stop();
        delete mac_audio_input;
        mac_audio_input = NULL;
    }
    mac_audio_input_device = NULL;
    mac_audio_input_channels = 0;
    mac_audio_input_sample_bytes = 0;
    mac_audio_input_sample_bits = 0;
    mac_audio_input_sample_type = QAudioFormat::Unknown;
    mac_audio_input_byte_order = QAudioFormat::LittleEndian;
}

static bool hv_mac_find_input_device(const QString &name, QAudioDeviceInfo *device)
{
    if (name.isEmpty() || name == "Default Input")
    {
        QAudioDeviceInfo default_device = QAudioDeviceInfo::defaultInputDevice();
        if (!default_device.isNull())
        {
            *device = default_device;
            return true;
        }
    }

    QList<QAudioDeviceInfo> devices = QAudioDeviceInfo::availableDevices(QAudio::AudioInput);
    for (int i = 0; i < devices.count(); ++i)
    {
        if (devices.at(i).deviceName() == name)
        {
            *device = devices.at(i);
            return true;
        }
    }
    return false;
}

static bool hv_mac_try_input_format(const QAudioDeviceInfo &device, const QAudioFormat &candidate, QAudioFormat *selected)
{
    if (!candidate.isValid())
        return false;
    if (!device.isFormatSupported(candidate))
        return false;
    *selected = candidate;
    return true;
}

static bool hv_mac_select_input_format(const QAudioDeviceInfo &device, int sample_rate, int bit_depth, QAudioFormat *selected)
{
    QAudioFormat candidate;
    candidate.setCodec("audio/pcm");
    candidate.setSampleRate(sample_rate);
    candidate.setChannelCount(2);
    candidate.setSampleSize(bit_depth);
    candidate.setSampleType(QAudioFormat::SignedInt);
    candidate.setByteOrder(QAudioFormat::LittleEndian);
    if (hv_mac_try_input_format(device, candidate, selected))
        return true;

    candidate.setChannelCount(1);
    if (hv_mac_try_input_format(device, candidate, selected))
        return true;

    if (bit_depth != 16)
    {
        candidate.setChannelCount(2);
        candidate.setSampleSize(16);
        if (hv_mac_try_input_format(device, candidate, selected))
            return true;

        candidate.setChannelCount(1);
        if (hv_mac_try_input_format(device, candidate, selected))
            return true;
    }

    QAudioFormat preferred = device.preferredFormat();
    if (preferred.isValid())
    {
        preferred.setCodec("audio/pcm");
        preferred.setSampleRate(sample_rate);
        if (preferred.channelCount() < 1)
            preferred.setChannelCount(1);
        if (preferred.channelCount() > 2)
            preferred.setChannelCount(2);
        if (hv_mac_try_input_format(device, preferred, selected))
            return true;

        preferred.setChannelCount(1);
        if (hv_mac_try_input_format(device, preferred, selected))
            return true;
    }

    return false;
}

static int hv_mac_read_s24(const unsigned char *src, QAudioFormat::Endian order)
{
    int sample = 0;
    if (order == QAudioFormat::BigEndian)
        sample = (int)src[2] | ((int)src[1] << 8) | ((int)src[0] << 16);
    else
        sample = (int)src[0] | ((int)src[1] << 8) | ((int)src[2] << 16);
    if (sample & 0x00800000)
        sample |= ~0x00ffffff;
    return sample;
}

static int hv_mac_read_s32(const unsigned char *src, QAudioFormat::Endian order)
{
    unsigned int sample = 0;
    if (order == QAudioFormat::BigEndian)
    {
        sample = (unsigned int)src[3]
               | ((unsigned int)src[2] << 8)
               | ((unsigned int)src[1] << 16)
               | ((unsigned int)src[0] << 24);
    }
    else
    {
        sample = (unsigned int)src[0]
               | ((unsigned int)src[1] << 8)
               | ((unsigned int)src[2] << 16)
               | ((unsigned int)src[3] << 24);
    }
    return (int)sample;
}

static unsigned int hv_mac_read_u32(const unsigned char *src, QAudioFormat::Endian order)
{
    return (unsigned int)hv_mac_read_s32(src, order);
}

static unsigned long long hv_mac_read_u64(const unsigned char *src, QAudioFormat::Endian order)
{
    unsigned long long sample = 0;
    if (order == QAudioFormat::BigEndian)
    {
        for (int i = 0; i < 8; ++i)
            sample = (sample << 8) | (unsigned long long)src[i];
    }
    else
    {
        for (int i = 7; i >= 0; --i)
            sample = (sample << 8) | (unsigned long long)src[i];
    }
    return sample;
}

static int hv_mac_scale_signed_sample(long long sample, int bits)
{
    if (bits < 1)
        return 0;
    if (bits < 24)
        sample <<= (24 - bits);
    else if (bits > 24)
        sample >>= (bits - 24);

    if (sample > 8388607LL)
        sample = 8388607LL;
    if (sample < -8388608LL)
        sample = -8388608LL;
    return (int)sample;
}

static int hv_mac_scale_unsigned_sample(unsigned long long sample, int bits)
{
    if (bits < 1)
        return 0;
    unsigned long long mid = 1ULL << (bits - 1);
    long long centered = (long long)sample - (long long)mid;
    return hv_mac_scale_signed_sample(centered, bits);
}

static int hv_mac_read_float_sample(const unsigned char *src, int sample_bits, QAudioFormat::Endian order)
{
    double sample = 0.0;
    if (sample_bits == 32)
    {
        unsigned int raw = hv_mac_read_u32(src, order);
        float value = 0.0f;
        memcpy(&value, &raw, sizeof(value));
        sample = value;
    }
    else if (sample_bits == 64)
    {
        unsigned long long raw = hv_mac_read_u64(src, order);
        double value = 0.0;
        memcpy(&value, &raw, sizeof(value));
        sample = value;
    }
    else
        return 0;

    if (sample > 1.0)
        sample = 1.0;
    if (sample < -1.0)
        sample = -1.0;
    return (int)(sample * 8388607.0);
}

void MsCore::rad_open_sound()
{
    rad_close_sound();

    rad_sound_state.read_error = 0;
    rad_sound_state.write_error = 0;
    rad_sound_state.underrun_error = 0;
    rad_sound_state.interupts = 0;
    rad_sound_state.rate_min = rad_sound_state.rate_max = -99;
    rad_sound_state.chan_min = rad_sound_state.chan_max = -99;
    rad_sound_state.msg1[0] = 0;
    rad_sound_state.err_msg[0] = 0;
    rad_sound_state.bad_device = 1;

    QAudioDeviceInfo device;
    QString device_name = QString::fromUtf8(rad_sound_state.dev_capt_name);
    if (!hv_mac_find_input_device(device_name, &device))
    {
        strncpy(rad_sound_state.err_msg, "Cannot find input device.", SC_SIZE_L - 1);
        rad_sound_state.err_msg[SC_SIZE_L - 1] = 0;
        return;
    }

    QAudioFormat format;
    if (!hv_mac_select_input_format(device, in_sample_rate, in_bitpersample, &format))
    {
        snprintf(rad_sound_state.err_msg, SC_SIZE_L,
                 "Unsupported input format %d Hz %d-bit.",
                 in_sample_rate, in_bitpersample);
        return;
    }

    mac_audio_input = new QAudioInput(device, format);
    mac_audio_input_channels = format.channelCount();
    mac_audio_input_sample_bits = format.sampleSize();
    mac_audio_input_sample_bytes = qMax(1, (mac_audio_input_sample_bits + 7) / 8);
    mac_audio_input_sample_type = format.sampleType();
    mac_audio_input_byte_order = format.byteOrder();

    int bytes_per_second = format.sampleRate() * format.channelCount() * mac_audio_input_sample_bytes;
    int buffer_bytes = (bytes_per_second * qMax(rad_sound_state.latency_millisecs, 40)) / 1000;
    if (buffer_bytes < 4096) buffer_bytes = 4096;
    mac_audio_input->setBufferSize(buffer_bytes);
    mac_audio_input_device = mac_audio_input->start();

    if (!mac_audio_input_device || mac_audio_input->state() == QAudio::StoppedState)
    {
        hv_mac_release_input();
        strncpy(rad_sound_state.err_msg, "Cannot open input device.", SC_SIZE_L - 1);
        rad_sound_state.err_msg[SC_SIZE_L - 1] = 0;
        return;
    }

    QByteArray selected_name = device.deviceName().toUtf8();
    snprintf(rad_sound_state.msg1, sizeof(rad_sound_state.msg1), "%s %d Hz %d ch %d-bit",
             selected_name.constData(), format.sampleRate(), format.channelCount(), format.sampleSize());
    rad_sound_state.rate_min = rad_sound_state.rate_max = format.sampleRate();
    rad_sound_state.chan_min = rad_sound_state.chan_max = format.channelCount();
    rad_sound_state.bad_device = 0;
    rad_sound_state.err_msg[0] = 0;
}

void MsCore::rad_close_sound()
{
    hv_mac_release_input();
    strncpy(rad_sound_state.err_msg, CLOSED_TEXT, SC_SIZE_L - 1);
    rad_sound_state.err_msg[SC_SIZE_L - 1] = 0;
    rad_sound_state.bad_device = 1;
}

int MsCore::alsa_read_sound()
{
    if (!mac_audio_input || !mac_audio_input_device || mac_audio_input_channels < 1 || mac_audio_input_sample_bytes < 1)
        return 0;

    if (mac_audio_input->state() == QAudio::StoppedState)
    {
        if (mac_audio_input->error() != QAudio::NoError)
            rad_sound_state.read_error++;
        return 0;
    }

    int bytes_per_frame = mac_audio_input_channels * mac_audio_input_sample_bytes;
    qint64 available = mac_audio_input_device->bytesAvailable();
    if (available < bytes_per_frame)
        available = mac_audio_input->bytesReady();
    if (available < bytes_per_frame)
        return 0;

    qint64 max_bytes = (qint64)SAMP_BUFFER_SIZE * bytes_per_frame;
    if (available > max_bytes)
        available = max_bytes;
    available -= (available % bytes_per_frame);
    if (available < bytes_per_frame)
        return 0;

    QByteArray data = mac_audio_input_device->read((int)available);
    if (data.size() < bytes_per_frame)
        return 0;

    int frames = data.size() / bytes_per_frame;
    int channel_index = rad_sound_state.channel_I;
    if (channel_index < 0) channel_index = 0;
    if (channel_index >= mac_audio_input_channels) channel_index = mac_audio_input_channels - 1;

    int *dat_t = new int[frames + 10];
    int count = 0;
    const unsigned char *src = (const unsigned char *)data.constData();

    for (int frame = 0; frame < frames; ++frame)
    {
        const unsigned char *sample_ptr = src + frame * bytes_per_frame + channel_index * mac_audio_input_sample_bytes;
        int sample = 0;

        if (mac_audio_input_sample_type == QAudioFormat::Float)
        {
            sample = hv_mac_read_float_sample(sample_ptr, mac_audio_input_sample_bits, mac_audio_input_byte_order);
        }
        else if (mac_audio_input_sample_type == QAudioFormat::SignedInt)
        {
            if (mac_audio_input_sample_bits == 8)
                sample = hv_mac_scale_signed_sample((signed char)sample_ptr[0], 8);
            else if (mac_audio_input_sample_bits == 16)
                sample = hv_mac_scale_signed_sample((short)((mac_audio_input_byte_order == QAudioFormat::BigEndian)
                         ? ((unsigned short)sample_ptr[1] | ((unsigned short)sample_ptr[0] << 8))
                         : ((unsigned short)sample_ptr[0] | ((unsigned short)sample_ptr[1] << 8))), 16);
            else if (mac_audio_input_sample_bits == 24)
                sample = hv_mac_scale_signed_sample(hv_mac_read_s24(sample_ptr, mac_audio_input_byte_order), 24);
            else if (mac_audio_input_sample_bits == 32)
                sample = hv_mac_scale_signed_sample(hv_mac_read_s32(sample_ptr, mac_audio_input_byte_order), 32);
            else
                continue;
        }
        else if (mac_audio_input_sample_type == QAudioFormat::UnSignedInt)
        {
            if (mac_audio_input_sample_bits == 8)
                sample = hv_mac_scale_unsigned_sample(sample_ptr[0], 8);
            else if (mac_audio_input_sample_bits == 16)
            {
                unsigned short raw = (mac_audio_input_byte_order == QAudioFormat::BigEndian)
                                   ? (unsigned short)sample_ptr[1] | ((unsigned short)sample_ptr[0] << 8)
                                   : (unsigned short)sample_ptr[0] | ((unsigned short)sample_ptr[1] << 8);
                sample = hv_mac_scale_unsigned_sample(raw, 16);
            }
            else if (mac_audio_input_sample_bits == 24)
            {
                unsigned int raw = (mac_audio_input_byte_order == QAudioFormat::BigEndian)
                                 ? (unsigned int)sample_ptr[2] | ((unsigned int)sample_ptr[1] << 8) | ((unsigned int)sample_ptr[0] << 16)
                                 : (unsigned int)sample_ptr[0] | ((unsigned int)sample_ptr[1] << 8) | ((unsigned int)sample_ptr[2] << 16);
                sample = hv_mac_scale_unsigned_sample(raw, 24);
            }
            else if (mac_audio_input_sample_bits == 32)
            {
                unsigned int raw = hv_mac_read_u32(sample_ptr, mac_audio_input_byte_order);
                sample = hv_mac_scale_unsigned_sample(raw, 32);
            }
            else
                continue;
        }
        else
            continue;

        dat_t[count] = sample;
        count++;
    }

    if (count > 0)
        ResampleAndFilter(dat_t, count);
    delete [] dat_t;
    return count;
}
#endif
