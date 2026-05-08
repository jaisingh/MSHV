include(MSHV_x86_64.pro)

TARGET = MSHV-OSX

CONFIG += sdk_no_version_check
QT += multimedia

QMAKE_MACOSX_DEPLOYMENT_TARGET = 11.0
QMAKE_INFO_PLIST = $$PWD/macos/Info.plist
ICON = $$PWD/macos/mshv_mac.icns

QMAKE_CC = /opt/homebrew/bin/gcc-15
QMAKE_CXX = /opt/homebrew/bin/g++-15
QMAKE_LINK = /opt/homebrew/bin/g++-15

DEFINES -= _LINUX_ __linux__ QESP_NO_UDEV
DEFINES += _MACOS_

QMAKE_CXXFLAGS -= -stdlib=libc++
QMAKE_LFLAGS -= -stdlib=libc++
QMAKE_CXXFLAGS -= -freorder-functions -funroll-all-loops
QMAKE_CXXFLAGS += -isystem /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1

HEADERS -= src/HvAlsaMixer/hvalsamixer.h \
 src/HvAlsaMixer/hvcbox.h \
 src/HvAlsaMixer/hvmixermain.h \
 src/HvAlsaMixer/hvrbutton.h \
 src/HvAlsaMixer/hvvtext.h

SOURCES -= src/HvMsCore/linsound_in.cpp \
 src/HvMsPlayer/libsound/linsound_out.cpp \
 src/HvRigControl/qexsp_1_2rc/qextserialenumerator_linux.cpp \
 src/HvAlsaMixer/hvalsamixer.cpp \
 src/HvAlsaMixer/hvmixermain.cpp \
 src/HvAlsaMixer/hvcbox.cpp \
 src/HvAlsaMixer/hvrbutton.cpp \
 src/HvAlsaMixer/hvvtext.cpp

RESOURCES -= src/HvAlsaMixer/hvalsamixer.qrc

SOURCES += src/HvMsCore/macsound_in.cpp \
 src/HvMsPlayer/libsound/macsound_out.cpp \
 src/HvRigControl/qexsp_1_2rc/qextserialenumerator_osx.cpp

QMAKE_LIBDIR += /opt/homebrew/lib
QMAKE_RPATHDIR += /opt/homebrew/lib

LIBS -= -lasound -lpulse-simple -lpulse
LIBS += -L/opt/homebrew/lib -lfftw3 -framework IOKit -framework CoreFoundation

DESTDIR = $$clean_path($$PWD/release/macos)
OBJECTS_DIR = $$clean_path($$PWD/build/macos/obj)
MOC_DIR = $$clean_path($$PWD/build/macos/moc)
RCC_DIR = $$clean_path($$PWD/build/macos/rcc)
UI_DIR = $$clean_path($$PWD/build/macos/ui)

QMAKE_POST_LINK += $$QMAKE_COPY_DIR $$shell_path($$PWD/bin/settings) $$shell_quote($$shell_path($$DESTDIR/$${TARGET}.app/Contents/Resources))
