dir=$1
files=$(ls $dir | tr ' ' '\n' | grep -v Untitled)

#만들다말았다
set -ex;
for file in $files
do
    echo $file
    original=$(ls "$dir/* $file") # "${dir}/Untitled\ ${file}"
    renameto=$dir/"Untitled"$file
    # mv $original $renameto
done
