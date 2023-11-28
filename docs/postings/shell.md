---
title: "Shell Script Practices"
parent: posts
last_modified_date: 2023-07-08
nav_order: 6
description: "HN에 소개 된 shell script practices 모음"
---

# Shell script Practices

## [How "Exit Traps" Can Make Your Bash Script More Robust and Reliable](http://redsymbol.net/articles/bash-exit-traps/)

`trap`을 이용해서 EXIT pseudo signal을 받을 수 있다. 이를이용해서 종료되는 시점에 훅을 걸 수 있다.
아래 예시 코드를 보자.

```sh
#!/bin/bash
function finish {
    # Your cleanup code here
}
trap finish EXIT
```

예를들어서 임시디렉토리를 만들고, 스크립트가 종료될때 디렉토리를 지운다면 아래처럼 만들 수 있다.
```sh
#!/bin/bash
scratch=$(mktemp -d -t tmp.XXX)
function finish {
    rm -rf "$scratch"
}
trap finish EXIT
```

`$scratch` directory 안에서 tmep file들을 처리한다고 생각해보자.

```sh
# Download every linux kernel ever.... FOR SCIENCE!
for major in {1..4}; do
  for minor in {0..99}; do
    for patchlevel in {0..99}; do
      tarball="linux-${major}-${minor}-${patchlevel}.tar.bz2"
      curl -q "http://kernel.org/path/to/$tarball" -o "$scratch/$tarball" || true
      if [ -f "$scratch/$tarball" ]; then
        tar jxf "$scratch/$tarball"
      fi
    done
  done
done
# magically merge them into some frankenstein kernel ...
# That done, copy it to a destination
cp "$scratch/frankenstein-linux.tar.bz2" "$1"
# Here at script end, the scratch directory is erased automatically
```

만약 여기서 trap 없이 directory를 지우려고 하면 굉장히 번거로워진다
```sh
#!/bin/bash
# DON'T DO THIS!
scratch=$(mktemp -d -t tmp.XXXXXXXXXX)

# Insert dozens or hundreds of lines of code here...

# All done, now remove the directory before we exit
rm -rf "$scratch"
```
- 에러가 발생해서 exit하면 `$scratch` 디렉토리는 지워지지 않아서 resource leak이 생긴다.
- script가 끝나기 전에 exit한다면 직접 각 exit point마다 rm command를 넣어놔야 한다.
- 유지보수도 어렵다. 중간에 새 구문을 추가한다면 지우는 로직을 추가하는것도 까먹기 쉽게 된다.

### Example: Keeping services up, no matter what

system admin task를 자동화 하는걸 생각해보자.
서버를 잠시 내리고 어떤 작업을 한 뒤에 서버를 다시 올려야 한다.

```sh
function finish {
    # re-start service
    sudo /etc/init.d/somthing start
}
trap finish EXIT
sudo /etc/init.d/something stop
# Do the work

# Allow the script to end and the trapped finish function to start the daemon back up.
```

### Example: Capping expensive resources

스크립트에서 비싼 리소스를 사용하는 경우, 스크립트가 실행되는 동안에만 필요하다면 리소스를 내리는데에도 활용할 수 있다.
custom AMI를 만드는 일반적인 패턴을 예시로 들면,
1. base AMI를 가지고 instance를 실행한다
2. 변경사항을 만든다.
3. image를 생성한다
4. instance를 종룧나다.

instance 종료를 하지 못하게되면 비용이 계속 나갈것이다.
따라서 아래처럼 스크립트를 만들어서 방지할 수 있다

```sh
#!/bin/bash
# define the base AMI ID somehow
ami=$1
# Store the temporary instance ID here
instnace=''
# While we are at int, let me show you another use for a scratch directory
scratch=$(mktemp -d -t tmp.XXXX)
function finish {
    if [ -n "instance" ]; then
        ec2-terminate-instances "$instance"
    fi
    rm -rf "$scratch"
}
trap finish EXIT
# This line runs the instance, and stores the program output (which shows the instance ID) in a file in the scratch directory
ec2-run-instances "$ami" > "$scratch/run-instance"
# Now extract the instance ID
instance=$(grep '^INSTANCE' "$scratch/run-instance" | cut -f 2)
```
마지막 라인에서 instance는 실행 상태이다. 따라서 instance에 필요한 변경사항을 수행하고 image를 생성하면 된다.
만약 스크립트가 실패하더라도, instance는 finish 함수에 의해서 종료될것이다.

그리고 다음처럼 마지막 라인이 scratch file을 읽지않고 aws cli를 실행하게 할수도 있긴한데,

(`instance=$(ec2-run-instances "$ami" | grep '^INSTANCE' | cut -f 2)`)

scratch file을 활용하는것이 로깅과 디버깅이 되어서 용이하다.

## [How To Write Idempotetn Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/)

### Simple commands

```sh
# Creating an empty file
touch exampl.txt

# Creating a directory
mkdir -p mydir

# Creating a symbolic link
# -f, --force: remove existing destination files
# -n, --no-dereference: treat LINK_NAME as a normal file if it is a symbolic link to a directory
ln -sfn source target

# Removing a file
rm -f example.txt
```

### Modifying a file

`/etc/fstab` 같은 이미 존재하는 파일에 라인을 추가하는 경우, 같은 스크립트가 두번 이상 실행될때 라인이 두번 추가되는것을 방지해야 한다.

```sh
echo '/dev/sda1 /mnt/dev/ ext4 defaults 0 0" | sudo tee -a /etc/fstab
```

위 커맨드를 두번 실행하게 되면 중복 라인이 생기므로 아래처럼 만들면 된다.

```sh
if ! grep -qF "/mnt/dev/ /etc/fstab; then
    echo '/dev/sda1 /mnt/dev/ ext4 defaults 0 0" | sudo tee -a /etc/fstab
fi
```
`-q ` 는 silent mode, `F` 는 `fixed string` mode 이다. grep은 `/mnt/dev` string 이 존재하지 않으면 silent fail을 하게 되므로 if 문 안의 커맨드를 실행하게 된다.

### Check if variable, file or directory exists
variable, file, directory를 가지고 어떤것을 하는 케이스를 생각해보자.
```sh
echo "complex set of rules" > /etc/conf/foo.txt
```

매번 같은 코드를 실행하면 안되지만, 그렇다고 매번 저 string이 존재하는지 확인하는건 상대적으로 비싼 연산이니, file의 존재 여부를 확인하는 방식도 쓸 수 있다.
```sh
if [ ! -f "/etc/conf/foo.txt" ]; then
    echo "complex set of rules" > /etc/conf/foo.txt
fi
```
`-f`: 파일 존재 여부, `-d`: 디렉토리 존재 여부, `-x`: file이 execution 권한 있는지 확인

나머지는 옵션은 아래 링크에서 볼 수 있다.

https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html

특정한 커맨드가 없을떄에만 커맨드를 설치하도록 하고싶으면 `-x`를 쓸 수 있따.

```sh
# Install 1password CLI
if ! [ -x "$(command -v op)" ]; then
    export OP_VERSION="v0.5.6-003"
    curl -sS -o 1password.zip https://cache.agilebits.com/dist/1P/op/pkg/${OP_VERSION}/op_linux_amd64_${OP_VERSION}.zip
    unzip 1password.zip op -d /usr/local/bin
    rm -f 1password.zip # 여기서 trap EXIT을 활용하면 좋을듯
fi
```

위 installation은 `op` 라는 이름의 binary를 `/usr/local/bin`에 설치하므로, 스크립트를 재실행하게되면 더이상 설치를 시도하지 않는다.

### Formating a Device
```sh
mkfs.ext4 "$VOLUME_NAME"
```

이 커맨드를 두번 이생 살힝하면 실패하게된다. idempotent하게 만드려면 `blkid` 를 쓰면 된다
```sh
blkid "$VOLUME_NAME" || mkfs.ext4 "$VOLUME_NAME"
```

`blkid`는 block device attribute를 출력하는건데, block device에 filesystem이 존재하지 않으면 에러가 나게 구성되어있으므로 `mkfs.ext4` 를 실행하게 된다.

### Mounting a Device
```sh
mount -o discard,defaults,noatime "$VOLUME_NAME" "$DATA_DIR"
```

이미 마운트 된 경우 위 커맨드는 실패한다.
따라서 `mountpoint` 커맨드를 활용하여 idempotent 하게 만들자.
```sh
if ! mountpoint -q "$DATA_DIR"; then
    mount -o discard,defaults,noatime "$VOLUME_NAME" "$DATA_DIR"
fi
```
`-q` flag는 silent mode이다.

## [Better Bash Scripting in 15 Minutes](http://robertmuth.blogspot.com/2012/08/better-bash-scripting-in-15-minutes.html)

### Variable Annotations
- `local`: function 내에서만 접근가능한 local variable
- `readonly`: read-only variable

### Favor `$()` over bacticks `(``)`

`$()` 은 quoting을 하지않고 nesting으로 쓸수있지만 backtick은 quoting이 필요하
```sh
echo "A-`echo B-\`echo C-\\\`echo D\\\`\``"
echo "A-$(echo B-$(echo C-$(echo D)))"
```

### Favor `[[]]` (double brackets) over `[]`
`[[]]` 은 예상하지 못한 pathname expansion을 피하고, 아래와 같은 operator를 사용할 수 있다.

`||, &&, <, -lt, =, ==, =~, -n, -z, -eq, -ne`

```sh
# single bracket
[ "${name}" \> "a" -o ${name} \< "m"]

# double bracket
[[ ${name} > "a" && "${name}" < "m"]]
```

### Regular Expressions/Globbing
```sh
t="abc123"
[[ "$t" == abc* ]]          # true  (globbing)
[[ "$t" == "abc*" ]]        # false (literal matching)
[[ "$t" =~ [abc]+[123]+ ]]  # true  (regular expression)
[[ "$t" =~ "abc*" ]]        # false (literal matching)
```

white space가 들어간경우 literal matching 대신 regex를 활용하려면 아래처럼 쓰면 된다
```sh
r="a b+"
[[ "a bbb" =~ $r ]]         # true
```

globbing은 case statement에서도 사용 가능하다.
```sh 
case $t in
abc*) <action> ;;
esac
```

### String Manipulation
bash는 string을 조작할때 여러가지 방법이 있다.

```sh
f="path1/path2/file.ext"

len="${#f}"             # 20 (string length)

# slicing: ${<var>:<start>} or ${<var>:<start>:<length>}
slice1="${f:6}"         # "path2/file.ext"
slice2="${f:6:5}"       # "path2"
slice3="${f: -8}"       # "file.ext" (-를 치기전에 space를 넣어줘야 한다)
```

globbing을 이용한 substitution
```
f="path1/path2/file.ext"

single_subst="${f/path?/x}"     # "x/path2/file.ext"
global_subst="${f//path?/x}"    # "x/x/file.ext"

#string splitting
readonly DIR_SEP="/"
array=(${f//${DIR_SEP}}/ )      # /를 space로 만들고, 이걸 괄호를 씌우면 어레이가 됨
second_dir="${array[1]}"        # "path2"
```

### Avoiding Temporary Files

일부 커맨드는 file name을 파라미터로 필요로 해서 pipeline을 쓸 수 없다.
이럴 땐 `<()` operator로 대체가능하다.
```sh
# download and diff two webpages
diff <(wget -O - url1) <(wget -O - url2)
```

또한 multi-line string을 stdin에 아래처럼 넘겨줄 수 있다.
```sh
# "MARKER" 대신 아무런 string이 들어가도 상관없다
command << MARKER
...
${var}
${cmd}
...
MARKER
```

parameter substitution을 동작하지 않게 하려면, 첫 MARKER에 quote를 붙이면 된다.
```sh
command << 'MARKER'
...
no substitution is happening here.
$ (dollar sign) is passed through verbatim.
...
MARKER
```

### Built-in Variables
- `$0`   name of the script
- `$n`   positional parameters to script/function
- `$$`   PID of the script
- `$!`    PID of the last command executed (and run in the background)
- `$?`   exit status of the last command  (${PIPESTATUS} for pipelined commands)
- `$#`   number of parameters to script/function
- `$@`  all parameters to script/function (sees arguments as separate word)
- `$*`    all parameters to script/function (sees arguments as single word)

Note
- `$*`   is rarely the right choice.
- `$@` handles empty parameter list and white-space within parameters correctly
- `$@` should usually be quoted like so "$@"

### Debugging

- 문법 체크: `bash -n myscript.sh`
- 실행하는 커맨드의 trace: `bash -v myscripts.sh` 또는 `set -o verbose`
- 전체 커맨드 trace: `bash -x myscripts.sh` 또는 `set -o xtrace`

### Signs you should not be using a bash script
- 몇백줄의 코드가 만들어질때
- data structure가 필요할 때
- quoting issue에 시간을 많이 쏟을 때
- string 조작이 많을 때
- 여러 프로그램을 호출하거나 pipeline을 할 필요가 없을때
- 성능이 중요할 때

### [Minimal safe Bash script template](https://betterdev.blog/minimal-safe-bash-script-template/)

bash script를 짤때 필요한 skeleton code 제공.

## [Use Bash Script Mode (Unless You Love Debugging)](http://redsymbol.net/articles/unofficial-bash-strict-mode/)

```sh
#!/bin/bash
set -euo pipefail
```

위 옵션을 추가하면 디버깅 하는 시간이 줄어들 것이다. 대부분 에러는 즉시 실패하고 원인을 찾기 쉬워진다.

### `set -e`
`set -e` 는 bash가 어떤 커맨드던지 non-zero exit status를 가지면 즉시 종료하게한다.
default는 이 옵션을 사용하지 않는것인데, 이렇게 쓰다보면 중간 커맨드가 실패한걸 알아차리기 어렵다.

### `set -u`
`set -u` 는 variable에 영향을 미친다. 이전에 선언한적 없는 변수를 사용할경우 즉시 종료시킨다.
```sh
#!/bin/bash
firstName="Aaron"
fullName="$firstname Maxwell" # firstname이 아니고 firstName으로 써야 맞음
echo "$fullName"
```

### `set -o pipefail`
pipeline 내에 있는 어떤 커맨드가 실패하는 경우, 이걸 pipeline 전체의 return code가 되게한다. pipefail을 넣지않으면 last command의 return code 이므로 중간 커맨드의 실패를 알아내기 힘들다
```sh
$ grep some-string /non/existence/file | sort
grep: /non/existent/file: No such file or directory
% echo $?
0 # sort의 exit code
```

하지만 `set -o pipefail`을 쓰게되면,
```sh
$ set -o pipefail
$ grep some-string /non/existence/file | sort
grep: /non/existent/file: No such file or directory
% echo $?
2
```

### [Issues & Solutions](http://redsymbol.net/articles/unofficial-bash-strict-mode/#:~:text=eager.%20%5B2%5D-,Issues%20%26%20Solutions,-I%27ve%20been%20using)

## [Common shell script mistakes](https://www.pixelbeat.org/programming/shell_script_mistakes.html)

### quoting
1. command, variable에서 double-quote를 써라. 특히 `$@` 는 double-quote를 꼭 써라.
2. `IFS="$(printf '\n\t')"` 를 쓰면 filename이나 space를 잘못 처리하는 리스크를 줄일 수 있다.
3. `*.pdf` 같은 패턴은 directory도 포함하기떄문에 `./*.pdf` 로 써야한다.
4. 더 있긴함..
