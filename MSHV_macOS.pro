QT += widgets network websockets multimedia
QMAKE_CXXFLAGS += -std=gnu++14 \
 -ffast-math \
 -fno-trapping-math \
 -funsafe-math-optimizations \
 -Wno-unknown-pragmas \
 -Wno-deprecated-declarations \
 -Wno-deprecated-register \
 -Wno-c++11-narrowing \
 -Wno-ignored-optimization-argument
CONFIG += qt \
 release \
 warn_on \
 console \
 sdk_no_version_check \
 -reduce \
 -rem

# macOS uses QtMultimedia (CoreAudio) instead of ALSA + PulseAudio.
# QESP_NO_UDEV: keep qextserialport from pulling in libudev.
DEFINES += _MACOS_ QESP_NO_UDEV

# FFTW from Homebrew. Pick the prefix from Qt's target architecture so the
# same .pro works for both:
#   * Apple Silicon native qmake -> QT_ARCH=arm64 -> /opt/homebrew
#   * Intel-arch qmake (under Rosetta) -> QT_ARCH=x86_64 -> /usr/local
HOMEBREW_PREFIX = /opt/homebrew
contains(QT_ARCH, x86_64): HOMEBREW_PREFIX = /usr/local
INCLUDEPATH += $$HOMEBREW_PREFIX/include
LIBS += -L$$HOMEBREW_PREFIX/lib -lfftw3

# qextserialenumerator on macOS uses IOKit + CoreFoundation.
LIBS += -framework CoreFoundation -framework IOKit -framework AppKit

# Compiler toolchain: Homebrew GCC is used so the C++ standard library
# matches the one FFTW/libstdc++ were built against.
QMAKE_CC = /opt/homebrew/bin/gcc-15
QMAKE_CXX = /opt/homebrew/bin/g++-15
QMAKE_LINK = /opt/homebrew/bin/g++-15
QMAKE_CXXFLAGS -= -stdlib=libc++
QMAKE_LFLAGS -= -stdlib=libc++
QMAKE_CXXFLAGS -= -freorder-functions -funroll-all-loops
QMAKE_CXXFLAGS += -isystem /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1

# App bundle metadata.
TARGET = MSHV-OSX
QMAKE_MACOSX_DEPLOYMENT_TARGET = 11.0
QMAKE_INFO_PLIST = $$PWD/macos/Info.plist
ICON = $$PWD/macos/mshv_mac.icns

# Output directories.
DESTDIR = $$clean_path($$PWD/release/macos)
OBJECTS_DIR = $$clean_path($$PWD/build/macos/obj)
MOC_DIR = $$clean_path($$PWD/build/macos/moc)
RCC_DIR = $$clean_path($$PWD/build/macos/rcc)
UI_DIR = $$clean_path($$PWD/build/macos/ui)

# Populate MSHV-OSX.app/Contents/Resources/ at build time so the .app is
# fully self-contained. macsound_in/out + main_ms resolve App_Path via
# mshv_app_data_path(), which on macOS points at Contents/Resources/.
RES_DIR = $${DESTDIR}/$${TARGET}.app/Contents/Resources
QMAKE_POST_LINK += mkdir -p $$shell_quote($$shell_path($$RES_DIR)) && \
    $$QMAKE_COPY_DIR $$shell_path($$PWD/bin/settings) $$shell_quote($$shell_path($$RES_DIR/settings)) && \
    mkdir -p $$shell_quote($$shell_path($$RES_DIR/RxWavs)) $$shell_quote($$shell_path($$RES_DIR/log)) $$shell_quote($$shell_path($$RES_DIR/ExportLog)) $$shell_quote($$shell_path($$RES_DIR/AllTxtMonthly)) $$shell_quote($$shell_path($$RES_DIR/Screenshots)) && \
    $$QMAKE_COPY $$shell_path($$PWD/macos/mshv_mac.icns) $$shell_quote($$shell_path($$RES_DIR/mshv_mac.icns)); \
    true

HEADERS = src/main_ms.h \
 src/config.h \
 src/config_msg_all.h \
 src/config_str_all.h \
 src/config_str_exc.h \
 src/config_str_con.h \
 src/config_band_all.h \
 src/config_str_sk.h \
 src/config_str_color.h \
 src/nhash.h \
 src/DisplayMs/display_ms.h \
 src/DisplayMs/HvCustomPalW/custompalw.h \
 src/HvStylePlastique/hvstyleplastique.h \
 src/HvStylePlastique/hvfontdialog.h \
 src/HvMsCore/mscore.h \
 src/SettingsMs/settings_ms.h \
 src/HvSMeter/hvsmeter_h.h \
 src/HvMsPlayer/msplayerhv.h \
 src/HvMsPlayer/libsound/config.h \
 src/HvMsPlayer/libsound/mpegsound.h \
 src/HvMsPlayer/libsound/mpegsound_locals.h \
 src/HvMsPlayer/libsound/genpom.h \
 src/HvMsPlayer/libsound/HvPackUnpackMsg/pack_unpack_msg.h \
 src/HvMsPlayer/libsound/HvPackUnpackMsg/pack_unpack_msg77.h \
 src/HvMsPlayer/libsound/HvGenMsk/config_rpt_msk40.h \
 src/HvMsPlayer/libsound/HvGenMsk/bpdecode_msk.h \
 src/HvMsPlayer/libsound/HvGenMsk/genmesage_msk.h \
 src/HvMsPlayer/libsound/HvGen65/gen65.h \
 src/HvMsPlayer/libsound/HvGenFt8/bpdecode_ft8_174_91.h \
 src/HvMsPlayer/libsound/HvGenFt8/gen_ft8.h \
 src/HvMsPlayer/libsound/HvGenFt8/gen_sfox.h \
 src/HvMsPlayer/libsound/HvGenFt4/gen_ft4.h \
 src/HvMsPlayer/libsound/HvGenFt2/gen_ft2.h \
 src/HvMsPlayer/libsound/HvGenQ65/gen_q65.h \
 src/HvMsPlayer/libsound/HvGenQ65/q65_subs.h \
 src/HvMsPlayer/libsound/HvRawFilter/hvrawfilter.h \
 src/HvTxW/HvAstroDataW/hvastrodataw.h \
 src/HvTxW/HvLogW/config_prop_all.h \
 src/HvTxW/HvLogW/hvlogw.h \
 src/HvTxW/HvMakros/hvmakros.h \
 src/HvTxW/HvRadioNetW/MessageClient.h \
 src/HvTxW/HvRadioNetW/NetworkMessage.h \
 src/HvTxW/HvRadioNetW/pimpl_h.h \
 src/HvTxW/HvRadioNetW/pimpl_impl.h \
 src/HvTxW/HvRadioNetW/pskreporterudptcp.h \
 src/HvTxW/HvRadioNetW/radionetw.h \
 src/HvTxW/HvRadioNetW/bcnlistw.h \
 src/HvTxW/config_rpt_all.h \
 src/HvTxW/hvtxw.h \
 src/HvTxW/hvqthloc.h \
 src/HvTxW/hvmsdb.h \
 src/HvTxW/hvinle.h \
 src/HvTxW/hvspinbox.h \
 src/HvTxW/hvcustomw.h \
 src/HvTxW/hvstditmmod.h \
 src/HvTxW/hvmultianswermodw.h \
 src/HvTextColor/hvtxtcolor.h \
 src/HvDecodeList/hvtooltip.h \
 src/HvDecodeList/hvcty.h \
 src/HvDecodeList/hvfilterdialog.h \
 src/HvDecodeList/decodelist.h \
 src/HvDecoderMs/decoderms.h \
 src/HvDecoderMs/decoderpom.h \
 src/HvDecoderMs/decoderq65.h \
 src/HvRigControl/hvrigcontrol.h \
 src/HvRigControl/qexsp_1_2rc/qextserialport.h \
 src/HvRigControl/qexsp_1_2rc/qextserialenumerator.h \
 src/HvRigControl/qexsp_1_2rc/qextserialport_global.h \
 src/HvRigControl/qexsp_1_2rc/qextserialport_p.h \
 src/HvRigControl/qexsp_1_2rc/qextserialenumerator_p.h \
 src/HvRigControl/HvRigCat/rigdef.h \
 src/HvRigControl/HvRigCat/hvutils.h \
 src/HvRigControl/HvRigCat/hvrigcatw.h \
 src/HvRigControl/HvRigCat/icom/icom.h \
 src/HvRigControl/HvRigCat/kenwood/kenwood.h \
 src/HvRigControl/HvRigCat/yaesu/yaesu.h \
 src/HvRigControl/HvRigCat/elecraft/elecraft.h \
 src/HvRigControl/HvRigCat/tentec/tentec.h \
 src/HvRigControl/HvRigCat/alinco/alinco.h \
 src/HvRigControl/HvRigCat/jrc/jrc.h \
 src/HvRigControl/HvRigCat/drake/drake.h \
 src/HvRigControl/HvRigCat/icmarine/icmarine.h \
 src/HvRigControl/HvRigCat/pcr/pcr.h \
 src/HvRigControl/HvRigCat/racal/racal.h \
 src/HvRigControl/HvRigCat/sdrs/sdrs.h \
 src/HvRigControl/HvRigCat/network/network.h \
 src/HvRigControl/HvRigCat/mits/mits.h \
 src/LabWidget/labw.h \
 src/HvSlider_V_Identif/hvslider_v_identif.h \
 src/HvAllTxt/hvalltxt.h \
 src/HvHelpMs/hvhelpms.h \
 src/HvHelpSkMs/hvhelpskms.h \
 src/HvAboutMsHv/hvaboutmshv.h \
 src/CpuWidget/cpusensorhv.h \
 src/CpuWidget/cpuwudget.h \
 src/CpuWidget/HvProgBarSlowH/hvprogbarslowh.h \
 src/HvButtons/hvbutton_left2.h \
 src/HvButtons/hvbutton_left4.h \
 src/HvButtons/hvmodbtsw.h \
 src/HvButtons/hvbutton_lrc.h \
 src/HvMsProc/hvmsproc.h \
 src/HvSlider_H/hvslider_h.h \
 src/HvAggressiveW/aggressiv_d.h
SOURCES = src/main.cpp \
 src/main_ms.cpp \
 src/nhash.cpp \
 src/DisplayMs/display_ms.cpp \
 src/DisplayMs/HvCustomPalW/custompalw.cpp \
 src/HvStylePlastique/hvstyleplastique.cpp \
 src/HvStylePlastique/hvfontdialog.cpp \
 src/HvMsCore/mscore.cpp \
 src/HvMsCore/macsound_in.cpp \
 src/SettingsMs/settings_ms.cpp \
 src/HvSMeter/hvsmeter_h.cpp \
 src/HvMsPlayer/msplayerhv.cpp \
 src/HvMsPlayer/libsound/fileinput.cpp \
 src/HvMsPlayer/libsound/rawplayer.cpp \
 src/HvMsPlayer/libsound/soundinputstream.cpp \
 src/HvMsPlayer/libsound/soundplayer.cpp \
 src/HvMsPlayer/libsound/wavetoraw.cpp \
 src/HvMsPlayer/libsound/macsound_out.cpp \
 src/HvMsPlayer/libsound/rawtodata.cpp \
 src/HvMsPlayer/libsound/soundplayer_wr.cpp \
 src/HvMsPlayer/libsound/rawtofile_wr.cpp \
 src/HvMsPlayer/libsound/genmesage.cpp \
 src/HvMsPlayer/libsound/genmesage_ms.cpp \
 src/HvMsPlayer/libsound/genpom.cpp \
 src/HvMsPlayer/libsound/HvPackUnpackMsg/pack_msg.cpp \
 src/HvMsPlayer/libsound/HvPackUnpackMsg/unpack_msg.cpp \
 src/HvMsPlayer/libsound/HvPackUnpackMsg/pack_unpack_msg77.cpp \
 src/HvMsPlayer/libsound/HvGenMsk/genmesage_msk.cpp \
 src/HvMsPlayer/libsound/HvGen65/gen65.cpp \
 src/HvMsPlayer/libsound/HvGenFt8/gen_ft8.cpp \
 src/HvMsPlayer/libsound/HvGenFt8/gen_sfox.cpp \
 src/HvMsPlayer/libsound/HvGenFt4/gen_ft4.cpp \
 src/HvMsPlayer/libsound/HvGenFt2/gen_ft2.cpp \
 src/HvMsPlayer/libsound/HvGenQ65/gen_q65.cpp \
 src/HvMsPlayer/libsound/HvGenQ65/q65_subs.cpp \
 src/HvMsPlayer/libsound/HvRawFilter/hvrawfilter.cpp \
 src/HvTxW/HvAstroDataW/hvastrodataw.cpp \
 src/HvTxW/HvLogW/hvlogw.cpp \
 src/HvTxW/HvMakros/hvmakros.cpp \
 src/HvTxW/HvRadioNetW/MessageClient.cpp \
 src/HvTxW/HvRadioNetW/NetworkMessage.cpp \
 src/HvTxW/HvRadioNetW/pskreporterudptcp.cpp \
 src/HvTxW/HvRadioNetW/radionetw.cpp \
 src/HvTxW/HvRadioNetW/bcnlistw.cpp \
 src/HvTxW/hvtxw.cpp \
 src/HvTxW/hvqthloc.cpp \
 src/HvTxW/hvmsdb.cpp \
 src/HvTxW/hvinle.cpp \
 src/HvTxW/hvspinbox.cpp \
 src/HvTxW/hvcustomw.cpp \
 src/HvTxW/hvstditmmod.cpp \
 src/HvTxW/hvmultianswermodw.cpp \
 src/HvTextColor/hvtxtcolor.cpp \
 src/HvDecodeList/hvtooltip.cpp \
 src/HvDecodeList/hvcty.cpp \
 src/HvDecodeList/hvfilterdialog.cpp \
 src/HvDecodeList/decodelist.cpp \
 src/HvDecoderMs/decoderms.cpp \
 src/HvDecoderMs/decoderpom.cpp \
 src/HvDecoderMs/decodermsk144.cpp \
 src/HvDecoderMs/decodermsk40.cpp \
 src/HvDecoderMs/decoderjtms.cpp \
 src/HvDecoderMs/decoderfsk441.cpp \
 src/HvDecoderMs/decoder6m.cpp \
 src/HvDecoderMs/decoderiscat.cpp \
 src/HvDecoderMs/decoderjt65.cpp \
 src/HvDecoderMs/decoderpi4.cpp \
 src/HvDecoderMs/decoderft8.cpp \
 src/HvDecoderMs/decoderft8var.cpp \
 src/HvDecoderMs/decodersfox.cpp \
 src/HvDecoderMs/decoderft4.cpp \
 src/HvDecoderMs/decoderft2.cpp \
 src/HvDecoderMs/decoderq65.cpp \
 src/HvRigControl/hvrigcontrol.cpp \
 src/HvRigControl/qexsp_1_2rc/qextserialport.cpp \
 src/HvRigControl/qexsp_1_2rc/qextserialenumerator.cpp \
 src/HvRigControl/qexsp_1_2rc/qextserialport_unix.cpp \
 src/HvRigControl/qexsp_1_2rc/qextserialenumerator_osx.cpp \
 src/HvRigControl/HvRigCat/hvutils.cpp \
 src/HvRigControl/HvRigCat/hvrigcatw.cpp \
 src/HvRigControl/HvRigCat/icom/icom.cpp \
 src/HvRigControl/HvRigCat/kenwood/kenwood.cpp \
 src/HvRigControl/HvRigCat/yaesu/yaesu.cpp \
 src/HvRigControl/HvRigCat/elecraft/elecraft.cpp \
 src/HvRigControl/HvRigCat/tentec/tentec.cpp \
 src/HvRigControl/HvRigCat/alinco/alinco.cpp \
 src/HvRigControl/HvRigCat/jrc/jrc.cpp \
 src/HvRigControl/HvRigCat/drake/drake.cpp \
 src/HvRigControl/HvRigCat/icmarine/icmarine.cpp \
 src/HvRigControl/HvRigCat/pcr/pcr.cpp \
 src/HvRigControl/HvRigCat/racal/racal.cpp \
 src/HvRigControl/HvRigCat/sdrs/sdrs.cpp \
 src/HvRigControl/HvRigCat/network/network.cpp \
 src/HvRigControl/HvRigCat/mits/mits.cpp \
 src/LabWidget/labw.cpp \
 src/HvSlider_V_Identif/hvslider_v_identif.cpp \
 src/HvAllTxt/hvalltxt.cpp \
 src/HvHelpMs/hvhelpms.cpp \
 src/HvHelpSkMs/hvhelpskms.cpp \
 src/HvAboutMsHv/hvaboutmshv.cpp \
 src/CpuWidget/cpusensorhv.cpp \
 src/CpuWidget/cpuwudget.cpp \
 src/CpuWidget/HvProgBarSlowH/hvprogbarslowh.cpp \
 src/HvButtons/hvbutton_left2.cpp \
 src/HvButtons/hvbutton_left4.cpp \
 src/HvButtons/hvmodbtsw.cpp \
 src/HvButtons/hvbutton_lrc.cpp \
 src/HvMsProc/hvmsproc.cpp \
 src/HvSlider_H/hvslider_h.cpp \
 src/HvAggressiveW/aggressiv_d.cpp
RESOURCES += src/main_ms.qrc \
 src/HvSMeter/hvsmeter_h.qrc \
 src/DisplayMs/display_ms.qrc \
 src/HvSlider_V_Identif/hvslider_v_identif.qrc \
 src/HvTxW/HvLogW/hvlogw.qrc \
 src/CpuWidget/HvProgBarSlowH/hvprogbarslowh.qrc \
 src/HvButtons/hvbuttons.qrc \
 src/HvSlider_H/hvslider_h.qrc
TEMPLATE = app
TRANSLATIONS += src/HvTranslations/mshv_bg.ts \
 src/HvTranslations/mshv_ru.ts \
 src/HvTranslations/mshv_zh.ts \
 src/HvTranslations/mshv_zhhk.ts \
 src/HvTranslations/mshv_eses.ts \
 src/HvTranslations/mshv_caes.ts \
 src/HvTranslations/mshv_ptpt.ts \
 src/HvTranslations/mshv_ptbr.ts \
 src/HvTranslations/mshv_roro.ts \
 src/HvTranslations/mshv_dadk.ts \
 src/HvTranslations/mshv_plpl.ts \
 src/HvTranslations/mshv_frfr.ts \
 src/HvTranslations/mshv_nbno.ts \
 src/HvTranslations/mshv_itit.ts \
 src/HvTranslations/mshv_cscz.ts
