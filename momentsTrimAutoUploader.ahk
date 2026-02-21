#Requires AutoHotkey v2.0

momentsPath := IniRead("trimUploader.ini", "location", "momentsPath", "")
if (momentsPath = "") {
    momentsPath := DirSelect()
}
trimPattern := IniRead("trimUploader.ini", "location", "trimPattern", "*_trim.mp4")
ziplineURL := IniRead("trimUploader.ini", "location", "ziplineURL", "PROVIDE ZIPLINE URL")
ziplineFolder := IniRead("trimUploader.ini", "location", "ziplineFolder", "PROVIDE FOLDER ID")
ziplineToken := IniRead("trimUploader.ini", "location", "ziplineToken", "PROVIDE ZIPLINE TOKEN")

IniWrite(momentsPath, "trimUploader.ini", "location", "momentsPath")
IniWrite(trimPattern, "trimUploader.ini", "location", "trimPattern")
IniWrite(ziplineURL, "trimUploader.ini", "location", "ziplineURL")
IniWrite(ziplineFolder, "trimUploader.ini", "location", "ziplineFolder")
IniWrite(ziplineToken, "trimUploader.ini", "location", "ziplineToken")

loop {
    uploadedURLs := ""
    uploadedFiles := 0
    Loop Files momentsPath "\" trimPattern, "F" {

        ; Build curl command
        cmd := 'curl -s -H "Authorization: ' ziplineToken '" '
        cmd .= '-H "x-zipline-original-name: true" '
        cmd .= '-H "x-zipline-p-format: name" '
        cmd .= '-H "x-zipline-folder: ' ziplineFolder '" '
        cmd .= '-H "x-zipline-filename: ' StrReplace(A_LoopFileName, ".mp4", "") '" '
        cmd .= '-F "file=@' A_LoopFileFullPath ';type=video/mp4" '
        cmd .= '"' ZiplineURL '/api/upload"'

        ; MsgBox(cmd)

        ; Run curl and capture output
        RunWait(A_ComSpec " /c " cmd " | clip", , "Hide")
        output := A_Clipboard

        ; Extract URL from JSON
        if RegExMatch(output, '"url":"(.*?)"', &m) {
            url := m[1]
            uploadedURLs .= url "`n"
            uploadedFiles++
            FileDelete(A_LoopFileFullPath)

            try {
            } catch Error {

            }
        } else {
            MsgBox "Failed to extract URL.`nResponse:`n" output
        }
    }

    if ( not uploadedURLs = "") {
        A_Clipboard := uploadedURLs
        TrayTip "Zipline Upload", "Uploaded " uploadedFiles " file(s)", 1
    }

    Sleep(5000)
}