#Requires AutoHotkey v2.0

momentsPath := IniRead("trimUploader.ini", "location", "momentsPath", "")
if (momentsPath = "") {
    momentsPath := DirSelect()
}
trimPattern := IniRead("trimUploader.ini", "location", "trimPattern", "*_trim.mp4")
ziplineURL := IniRead("trimUploader.ini", "location", "ziplineURL", "PROVIDE ZIPLINE URL")
ziplineFolder := IniRead("trimUploader.ini", "location", "ziplineFolder", "PROVIDE FOLDER ID")
ziplineToken := IniRead("trimUploader.ini", "location", "ziplineToken", "PROVIDE ZIPLINE TOKEN")
chunkSize := IniRead("trimUploader.ini", "location", "chunkSize", "26214400")
chunkThreshold := IniRead("trimUploader.ini", "location", "chunkThreshold", "99614720")

IniWrite(momentsPath, "trimUploader.ini", "location", "momentsPath")
IniWrite(trimPattern, "trimUploader.ini", "location", "trimPattern")
IniWrite(ziplineURL, "trimUploader.ini", "location", "ziplineURL")
IniWrite(ziplineFolder, "trimUploader.ini", "location", "ziplineFolder")
IniWrite(ziplineToken, "trimUploader.ini", "location", "ziplineToken")
IniWrite(chunkSize, "trimUploader.ini", "location", "chunkSize")
IniWrite(chunkThreshold, "trimUploader.ini", "location", "chunkThreshold")

loop {
    uploadedURLs := ""
    uploadedFiles := 0
    Loop Files momentsPath "\" trimPattern, "F" {
        ; Check file size to avoid upload mid export
        fileSize := 0
        while (fileSize < FileGetSize()) {
            fileSize := FileGetSize()
            Sleep(200)
        }

        chunkNum := Floor(fileSize / chunkSize)
        filePath := A_LoopFileFullPath
        fileName := A_LoopFileName

        if (chunkNum > 0) {
            ; -------------------------
            ; 2. UPLOAD CHUNKS
            ; -------------------------
            fileToUpload := FileOpen(filePath, "r")
            chunkIndex := 0
            partialIdentifier := ""
            mime := "video/mp4"

            while !fileToUpload.AtEOF {
                chunk := fileToUpload.Read(chunkSize)

                tmpChunk := A_Temp "\chunk.tmp"
                try {
                    FileDelete tmpChunk
                } catch Error {
                }
                FileAppend chunk, tmpChunk, "RAW"
                MsgBox FileGetSize(tmpChunk)

                uploadCmd := 'curl -s -X POST '
                ; uploadCmd .= '-H "content-type: multipart/form-data;" '
                uploadCmd .= Format('-H "Authorization: {1}" ', ziplineToken)
                uploadCmd .= '-H "x-zipline-format: name" '
                uploadCmd .= '-H "x-zipline-original-name: true" '
                uploadCmd .= Format('-H "x-zipline-p-content-length: {1}" ', fileSize)
                uploadCmd .= Format('-H "x-zipline-p-content-type: {1}" ', mime)
                uploadCmd .= Format('-H "x-zipline-p-filename: {1}" ', fileName)
                ; uploadCmd .= Format('-H "x-zipline-folder: {1}" ', ziplineFolder)
                if (chunkIndex > 0) {
                    uploadCmd .= Format('-H "x-zipline-p-identifier: {1}" ', partialIdentifier)
                }
                if (chunkIndex = chunkNum) {
                    uploadCmd .= '-H "x-zipline-p-lastchunk: true" '
                } else {
                    uploadCmd .= '-H "x-zipline-p-lastchunk: false" '
                }
                uploadCmd .= Format('-F "file=@{1}" ', tmpChunk)
                uploadCmd .= Format('"{1}/api/upload/partial"', ziplineURL,)

                MsgBox uploadCmd
                resp := RunWaitGet(uploadCmd)
                partialResult := JsonExtract(resp, "partialSuccess")

                if (chunkIndex = 0) {
                    partialIdentifier := JsonExtract(resp, "partialIdentifier")
                }

                if !partialResult {
                    MsgBox "Chunk upload failed at index " chunkIndex "`nResponse:`n" resp
                    return
                }

                chunkIndex++
            }

            fileToUpload.Close()

            finishResp := RunWaitGet(resp)
            finalUrl := JsonExtract(finishResp, "url")
        }

        ; Extract URL from JSON
        if ( not finalUrl = "") {
            uploadedURLs .= finalUrl "`n"
            uploadedFiles++

            try {
                FileDelete(A_LoopFileFullPath)
            } catch Error {

            }
        } else {
            MsgBox "Failed to extract URL.`nResponse:`n" finishResp
        }
    }

    if ( not uploadedURLs = "") {
        A_Clipboard := uploadedURLs
        TrayTip "Zipline Upload", "Uploaded " uploadedFiles " file(s)", 1
    }

    Sleep(5000)
}

RunWaitGet(cmd, options := "Hide") {
    tmp := A_Temp "\curl_out.txt"
    RunWait(A_ComSpec ' /c ' cmd ' > "' tmp '"', , options)
    return FileRead(tmp)
}

JsonExtract(json, key) {
    if RegExMatch(json, '"' key '":"(.*?)"', &m)
        return m[1]
    return ""
}