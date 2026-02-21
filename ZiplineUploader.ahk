#Requires AutoHotkey v2.0
#SingleInstance Force

; === PARAMETERS ===
; A_Args[1] = token
; A_Args[2..n] = files

if A_Args.Length < 2 {
    install := MsgBox("Usage:`nzipline-upload.ahk <token> <file1> <file2> ...`n`nInstall to windows send to context menu?", "Zipline Uploader", "YN")

    if (install = "Yes") {
        if (!DirExist(A_AppData "\ZiplineUploader")) {
            DirCreate(A_AppData "\ZiplineUploader")
        }
        FileCopy(A_ScriptFullPath, A_AppData "\ZiplineUploader\ZiplineUploader.exe", true)
        token := ""
        if (FileExist(A_WorkingDir "\token.txt")) {
            token := FileRead(A_WorkingDir "\token.txt")
        } else {
            tokenInput := InputBox("Provide your Zipline API token (found in your profile settings):", "Zipline Uploader")
            token := tokenInput.Value
        }
        sendTo := "`"" A_AppData "\ZiplineUploader\ZiplineUploader.exe`""
        FileCreateShortcut(sendTo, A_AppData "\Microsoft\Windows\SendTo\Zipline Uploader.lnk", A_AppData "\ZiplineUploader", token)
    }
    ExitApp
}

Token := A_Args[1]
ZiplineURL := "https://zipline.zjamnik.giize.com"

; Collect files
files := A_Args.Clone()
files.RemoveAt(1) ; remove token
uploadedFiles := 0
uploadedURLs := ""

for fil in files {
    SplitPath fil, &name, &dir, &ext

    ; Determine MIME type
    mime := "application/octet-stream" ; default fallback

    switch ext {
        ; Video
        case "mp4": mime := "video/mp4"
        case "m4v": mime := "video/x-m4v"
        case "mov": mime := "video/quicktime"
        case "mkv": mime := "video/x-matroska"
        case "webm": mime := "video/webm"
        case "avi": mime := "video/x-msvideo"
        case "wmv": mime := "video/x-ms-wmv"
        case "flv": mime := "video/x-flv"
        case "mpeg", "mpg": mime := "video/mpeg"
        case "3gp": mime := "video/3gpp"
        case "3g2": mime := "video/3gpp2"

            ; Audio
        case "mp3": mime := "audio/mpeg"
        case "wav": mime := "audio/wav"
        case "flac": mime := "audio/flac"
        case "ogg": mime := "audio/ogg"
        case "m4a": mime := "audio/mp4"
        case "aac": mime := "audio/aac"
        case "opus": mime := "audio/opus"
        case "wma": mime := "audio/x-ms-wma"

            ; Images
        case "jpg", "jpeg": mime := "image/jpeg"
        case "png": mime := "image/png"
        case "gif": mime := "image/gif"
        case "webp": mime := "image/webp"
        case "bmp": mime := "image/bmp"
        case "tiff", "tif": mime := "image/tiff"
        case "svg": mime := "image/svg+xml"
        case "heic": mime := "image/heic"
        case "heif": mime := "image/heif"

            ; Documents
        case "pdf": mime := "application/pdf"
        case "txt": mime := "text/plain"
        case "md": mime := "text/markdown"
        case "html": mime := "text/html"
        case "css": mime := "text/css"
        case "csv": mime := "text/csv"
        case "json": mime := "application/json"
        case "xml": mime := "application/xml"

            ; Archives / binaries
        case "zip": mime := "application/zip"
        case "rar": mime := "application/vnd.rar"
        case "7z": mime := "application/x-7z-compressed"
        case "tar": mime := "application/x-tar"
        case "gz": mime := "application/gzip"
        case "bz2": mime := "application/x-bzip2"
        case "exe": mime := "application/vnd.microsoft.portable-executable"
        case "bin": mime := "application/octet-stream"
    }

    ; Build curl command
    cmd := 'curl -s -H "Authorization: ' Token '" '
    cmd .= '-H "x-zipline-original-name: true" '
    cmd .= '-H "x-zipline-p-format: name" '
    cmd .= '-F "file=@' fil ';type=' mime '" '
    cmd .= '-F "filename=' name '" '
    cmd .= '"' ZiplineURL '/api/upload"'

    ; Run curl and capture output
    RunWait(A_ComSpec " /c " cmd " | clip", , "Hide")
    output := A_Clipboard

    ; Extract URL from JSON
    if RegExMatch(output, '"url":"(.*?)"', &m) {
        url := m[1]
        uploadedURLs .= url "`n"
        uploadedFiles++
    } else {
        MsgBox "Failed to extract URL.`nResponse:`n" output
        ExitApp
    }
}

; Copy to clipboard
A_Clipboard := uploadedURLs

; Notification
TrayTip "Zipline Upload", "Uploaded " uploadedFiles " file(s)", 1

Sleep 3000
ExitApp