(
  echo "group,path,file"
  jq -r '
    # Collect only valid dup-groups anywhere in the document:
    [ .. | objects | select(has("fileList") and (.fileList|type=="array")) ] 
    | to_entries[]
    | .key as $group
    | .value.fileList[]
    | .filePath as $fp
    | [
        $group,
        ($fp | sub("[^/]+$"; "")),   # directory (keeps trailing /)
        ($fp | sub(".*/"; ""))      # filename
      ]
    | @csv
  ' dupes.json
)
