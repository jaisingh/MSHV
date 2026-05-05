#ifndef HVAPPFILES_H
#define HVAPPFILES_H

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QString>

static inline QString HvAppResourceRoot()
{
#if defined _MACOS_
    return QDir::cleanPath(QCoreApplication::applicationDirPath() + "/../Resources");
#else
    return QCoreApplication::applicationDirPath();
#endif
}

static inline QString HvAppWritableRoot()
{
#if defined _MACOS_
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (!path.isEmpty())
        return path;
#endif
    return QCoreApplication::applicationDirPath();
}

static inline QString HvAppResourcePath(const QString &relative_path)
{
    return QDir(HvAppResourceRoot()).filePath(relative_path);
}

static inline QString HvAppWritablePath(const QString &relative_path)
{
    return QDir(HvAppWritableRoot()).filePath(relative_path);
}

static inline bool HvCopyTreeIfMissing(const QString &source_path, const QString &dest_path)
{
    QFileInfo source_info(source_path);
    if (!source_info.exists())
        return false;

    if (source_info.isDir())
    {
        QDir().mkpath(dest_path);
        QDir source_dir(source_path);
        QFileInfoList entries = source_dir.entryInfoList(QDir::NoDotAndDotDot | QDir::AllEntries);
        for (int i = 0; i < entries.count(); ++i)
        {
            QString name = entries.at(i).fileName();
            HvCopyTreeIfMissing(entries.at(i).absoluteFilePath(), QDir(dest_path).filePath(name));
        }
        return true;
    }

    if (QFileInfo(dest_path).exists())
        return true;

    QDir().mkpath(QFileInfo(dest_path).absolutePath());
    return QFile::copy(source_path, dest_path);
}

static inline void HvPrepareAppDataLayout()
{
#if defined _MACOS_
    QString writable_root = HvAppWritableRoot();
    if (writable_root.isEmpty())
        return;

    QDir().mkpath(writable_root);
    HvCopyTreeIfMissing(HvAppResourcePath("settings"), HvAppWritablePath("settings"));
    QDir().mkpath(HvAppWritablePath("log"));
    QDir().mkpath(HvAppWritablePath("ExportLog"));
    QDir().mkpath(HvAppWritablePath("RxWavs"));
    QDir().mkpath(HvAppWritablePath("Screenshots"));
    QDir().mkpath(HvAppWritablePath("AllTxtMonthly"));
#endif
}

#endif
