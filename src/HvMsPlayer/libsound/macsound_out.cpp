#include "mpegsound.h"

#if defined _MACOS_
#include <QAudio>
#include <QAudioDeviceInfo>
#include <QAudioFormat>
#include <QAudioOutput>
#include <QIODevice>
#include <QString>
#include <QtGlobal>
#include <unistd.h>

static QAudioOutput *mac_audio_output = NULL;
static QIODevice *mac_audio_output_device = NULL;
static QString mac_output_device_name;

static void hv_mac_release_output()
{
    if (mac_audio_output)
    {
        mac_audio_output->stop();
        delete mac_audio_output;
        mac_audio_output = NULL;
    }
    mac_audio_output_device = NULL;
}

static bool hv_mac_find_output_device(const QString &name, QAudioDeviceInfo *device)
{
    if (name.isEmpty() || name == "Default Output")
    {
        QAudioDeviceInfo default_device = QAudioDeviceInfo::defaultOutputDevice();
        if (!default_device.isNull())
        {
            *device = default_device;
            return true;
        }
    }

    QList<QAudioDeviceInfo> devices = QAudioDeviceInfo::availableDevices(QAudio::AudioOutput);
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

void Rawplayer::lin_destroy()
{
    hv_mac_release_output();
}

bool Rawplayer::lin_initialize(char *device_name, int)
{
    mac_output_device_name = QString::fromUtf8(device_name ? device_name : "");
    return true;
}

bool Rawplayer::lin_resetsoundtype()
{
    hv_mac_release_output();

    QAudioDeviceInfo device;
    if (!hv_mac_find_output_device(mac_output_device_name, &device))
        return false;

    QAudioFormat format;
    format.setCodec("audio/pcm");
    format.setSampleRate(rawspeed);
    format.setChannelCount(rawchannels);
    format.setSampleSize(rawsamplesize);
    format.setSampleType(QAudioFormat::SignedInt);
    format.setByteOrder(QAudioFormat::LittleEndian);

    if (!device.isFormatSupported(format))
        return false;

    mac_audio_output = new QAudioOutput(device, format);
    int sample_bytes = qMax(1, rawsamplesize / 8);
    int bytes_per_second = rawspeed * rawchannels * sample_bytes;
    int buffer_bytes = (bytes_per_second * qMax(Rawplayer::buffering, 400)) / 1000;
    if (buffer_bytes < audiobuffersize * 2) buffer_bytes = audiobuffersize * 2;
    mac_audio_output->setBufferSize(buffer_bytes);
    mac_audio_output_device = mac_audio_output->start();

    if (!mac_audio_output_device || mac_audio_output->state() == QAudio::StoppedState)
    {
        hv_mac_release_output();
        return false;
    }

    return true;
}

bool Rawplayer::lin_putblock(void *buffer, int size)
{
    if (!mac_audio_output || !mac_audio_output_device)
        return false;

    char *data = (char *)buffer;
    int remaining = size;
    int idle_loops = 0;

    while (remaining > 0)
    {
        if (mac_audio_output->state() == QAudio::StoppedState && mac_audio_output->error() != QAudio::NoError)
            return false;

        qint64 written = mac_audio_output_device->write(data, remaining);
        if (written > 0)
        {
            data += written;
            remaining -= (int)written;
            idle_loops = 0;
            continue;
        }
        if (written < 0)
            return false;

        usleep(1000);
        idle_loops++;
        if (idle_loops > 5000)
            return false;
    }

    return true;
}
#endif
