#!/bin/sh
# runcocoa.sh - Run any Cocoa code from the command line
# 
# Michael Tyson, A Tasty Pixel <michael@atastypixel.com>
#
# modifications by: maicki, xinsight

#  Check parameters and set settings
ccflags="";
includes="";
usegdb=;
uselldb=;
usearc=;
ios=;
iossdk="6.1";
iossdkpath=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${iossdk}.sdk
file=;
includemain=yes;

while [ "${1:0:1}" = "-" ]; do
	if [ "$1" = "-include" ]; then
		shift;
		printf -v includes "$includes\n#import <$1>";
	elif [ "$1" = "-gdb" ]; then
		usegdb=yes;
	elif [ "$1" = "-lldb" ]; then
		uselldb=yes;
		usegdb=;
	elif [ "$1" = "-ios" ]; then
		ios=yes;
	elif [ "$1" = "-nomain" ]; then
		includemain=;
	elif [ "$1" = "-noarc" ]; then
		usearc=;
	elif [ "$1" = "-file" ]; then
		file="$2";
	else
		ccflags="$ccflags $1 $2";
		shift;
	fi;
	shift;
done;

# Read the code from a file
commands=$*
if [ "$file" ]; then
	commands=`cat $file`
fi

if [ "$ios" ]; then
	printf -v includes "$includes\n#import <UIKit/UIKit.h>";
else
	printf -v includes "$includes\n#import <Cocoa/Cocoa.h>";
fi

# Use the appropriate template
if [ "$includemain" ]; then
	if [ "$usearc" ]; then
		cat > /tmp/runcocoa.m <<-EOF
		$includes
		int main(int argc, char *argv[]) {
			@autoreleasepool {
			  $commands;  
			}
		}
		EOF
	else
		cat > /tmp/runcocoa.m <<-EOF
		$includes
		int main (int argc, const char * argv[]) {
			NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		  	$commands;
		  	[pool drain];
		  	return 0;
		}
		EOF
	fi
else
	cat > /tmp/runcocoa.m <<-EOF
		$includes
		$commands;
	EOF
fi

if [ "$ios" ]; then

  if [ ! -d $iossdkpath ]; then
    echo "iOS SDK not found: ${iossdkpath}";
    exit 1;
  fi

	compiler="/usr/bin/env llvm-gcc \
				-x objective-c -arch i386 -fmessage-length=0 -pipe -std=c99 -fpascal-strings -O0 \
				-isysroot ${iossdkpath} -fexceptions -fasm-blocks \
				-mmacosx-version-min=10.6 -gdwarf-2 -fvisibility=hidden -fobjc-abi-version=2 -fobjc-legacy-dispatch -D__IPHONE_OS_VERSION_MIN_REQUIRED=40000 \
				-Xlinker -objc_abi_version -Xlinker 2 -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreText";

else
	export MACOSX_DEPLOYMENT_TARGET=10.6
	compiler="/usr/bin/env clang -O0 -std=c99 -framework Foundation -framework Cocoa";
fi

if [ "$usearc" ]; then
	compiler=$compiler" -fobjc-arc";
fi

if ! $compiler /tmp/runcocoa.m $ccflags -o /tmp/runcocoa-output; then
	exit 1;
fi

if [ "$usegdb" ]; then
  DBCMD=/tmp/runcocoa-gdb
  # start interactive gdb session. main is not initially defined
	cat > $DBCMD << EOF
set breakpoint pending on
break main
run
EOF
  gdb -x $DBCMD /tmp/runcocoa-output
  rm $DBCMD
elif [ "$uselldb" ]; then
  # lldb can only execute commands from .lldbinit ?
  cat > .lldbinit << EOF
b main
run
EOF
	DYLD_ROOT_PATH="${iossdkpath}" lldb /tmp/runcocoa-output
  rm .lldbinit
else
  if [ "$ios" ]; then
	  DYLD_ROOT_PATH="${iossdkpath}" /tmp/runcocoa-output
  else
	  /tmp/runcocoa-output
  fi
fi
rm /tmp/runcocoa-output /tmp/runcocoa.m 2>/dev/null
