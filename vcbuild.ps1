$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path
cd $scriptRoot

if(($($args[0]) -eq "help") -or ($($args[0]) -eq "--help") -or ($($args[0]) -eq "-help") -or ($($args[0]) -eq "?") -or ($($args[0]) -eq "-?") -or ($($args[0]) -eq "--?") -or ($($args[0]) -eq "/q")){
    echo  "vcbuild.ps1 [debug/release] [msi] [test/test-ci/test-all/test-uv/test-inspector/test-internet/test-pummel/test-simple/test-message/test-async-hooks] [clean] [noprojgen] [small-icu/full-icu/without-intl] [nobuild] [sign] [x86/x64] [vs2015/vs2017] [download-all] [enable-vtune] [lint/lint-ci] [no-NODE-OPTIONS]"
    echo  "Examples:"
    echo  "vcbuild.ps1                : builds release build"
    echo  "vcbuild.ps1 debug          : builds debug build"
    echo  "vcbuild.ps1 release msi    : builds release build and MSI installer package"
    echo  "vcbuild.ps1 test           : builds debug build and runs tests"
    echo  "vcbuild.ps1 build-release  : builds the release distribution as used by nodejs.org"
    echo  "vcbuild.ps1 enable-vtune   : builds nodejs with Intel VTune profiling support to profile JavaScript"
    exit
}

echo "Process arguments."
Set-Variable -Name "config" -Value "Release"
Set-Variable -Name "target" -Value "Build"
Set-Variable -Name "target_arch" -Value "x64"
Set-Variable -Name "target_env"
Set-Variable -Name "noprojgen"
Set-Variable -Name "nobuild"
Set-Variable -Name "sign"
Set-Variable -Name "nosnapshot"
Set-Variable -Name "cctest_args"
Set-Variable -Name "test_args"
Set-Variable -Name "package"
Set-Variable -Name "msi"
Set-Variable -Name "upload"
Set-Variable -Name "licensertf"
Set-Variable -Name "jslint"
Set-Variable -Name "cpplint"
Set-Variable -Name "build_testgc_addon"
Set-Variable -Name "noetw"
Set-Variable -Name "noetw_msi_arg"
Set-Variable -Name "noperfctr"
Set-Variable -Name "noperfctr_msi_arg"
Set-Variable -Name "i18n_arg"
Set-Variable -Name "download_arg"
Set-Variable -Name "build_release"
Set-Variable -Name "enable_vtune_arg"
Set-Variable -Name "configure_flags"
Set-Variable -Name "build_addons"
Set-Variable -Name "dll"
Set-Variable -Name "enable_static"
Set-Variable -Name "build_addons_napi"
Set-Variable -Name "test_node_inspect"
Set-Variable -Name "test_check_deopts"
Set-Variable -Name "js_test_suites" -Value "async-hooks inspector known_issues message parallel sequential"
Set-Variable -Name "common_test_suites" -Value "$js_test_suites doctool addons addons-napi"
Set-Variable -Name "build_addons" -Value 1
Set-Variable -Name "build_addons_napi" -Value 1


function ArgsDone {
    if ($build_release -ne $null){
        Set-Variable -Name "config" -Value "release"
        Set-Variable -Name "package" -Value 1
        Set-Variable -Name "msi" -Value 1
        Set-Variable -Name "licensertf" -Value 1
        Set-Variable -Name "download_arg" -Value "--download=all"
        Set-Variable -Name "i18n_arg" -Value "small-icu"
    }
}

function NoDepsICU {
    echo "no deps ICU"
    GetNodeVersion
}

function GetNodeVersion {
    Set-Variable -Name "NODE_VERSION"
    Set-Variable -Name "TAG"
    Set-Variable -Name "FULL_VERSION"


    #Call as subroutine for validation of python
    python test.py

    <#
call :run-python tools\getnodeversion.py > nul
for /F "tokens=*" %%i in ('%VCBUILD_PYTHON_LOCATION% tools\getnodeversion.py') do set NODE_VERSION=%%i
if not defined NODE_VERSION (
  echo Cannot determine current version of Node.js
  exit /b 1
)

if not defined DISTTYPE set DISTTYPE=release
if "%DISTTYPE%"=="release" (
  set FULLVERSION=%NODE_VERSION%
  goto distexit
)
if "%DISTTYPE%"=="custom" (
  if not defined CUSTOMTAG (
    echo "CUSTOMTAG is not set for DISTTYPE=custom"
    exit /b 1
  )
  set TAG=%CUSTOMTAG%
)
if not "%DISTTYPE%"=="custom" (
  if not defined DATESTRING (
    echo "DATESTRING is not set for nightly"
    exit /b 1
  )
  if not defined COMMIT (
    echo "COMMIT is not set for nightly"
    exit /b 1
  )
  if not "%DISTTYPE%"=="nightly" (
    if not "%DISTTYPE%"=="next-nightly" (
      echo "DISTTYPE is not release, custom, nightly or next-nightly"
      exit /b 1
    )
  )
  set TAG=%DISTTYPE%%DATESTRING%%COMMIT%
)
set FULLVERSION=%NODE_VERSION%-%TAG%
#>

}

function AssignPathToNode_exe {
    Set-Variable -Name "node_exe" -Value "$config\node.exe"
    Set-Variable -Name "node_gyp_exe" -Value "$node_exe deps\npm\node_modules\node-gyp\bin\node-gyp"
    if ($target_env -eq "vs2015"){Set-Variable -Name "node_gyp_exe" -Value "$node_gyp_exe --msvs_version=2015"}
    if ($target_env -eq "vs2017"){Set-Variable -Name "node_gyp_exe" -Value "$node_gyp_exe --msvs_version=2017"}

    if ($config -eq "Debug"){Set-Variable -Name "configure_flags" -Value "$configure_flags --debug"}
    if ($nosnapshot -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --without-snapshot"}
    if ($noetw -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --without-etw"; Set-Variable -Name "noetw_msi_arg" -Value "/p:NoETW=1"}
    if ($noperfctr -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --without-perfctr"; Set-Variable -Name "nopeffctr_msi_arg" -Value "/p:NoPerfCtr=1"}
    if ($release_urlbase -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --release-urlbase=$release_urlbase"}
    if ($download_arg -ne $null){Set-Variable -Name "configure_flags" -Value "$download_arg"}
    if ($enable_vtune_arg -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --enable-vtune-profiling"}
    if ($dll -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --shared"}
    if ($enable_static -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --enable-static"}
    if ($no_NODE_OPTIONS -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags --without-node-options"}

    if ($i18n_arg -eq "full-icu"){Set-Variable -Name "configure_flags" -Value "$configure_flags --with-intl=full-icu"}
    if ($i18n_arg -eq "small-icu"){Set-Variable -Name "configure_flags" -Value "$configure_flags --with-intl=small-icu"}
    if ($i18n_arg -eq "intl-none"){Set-Variable -Name "configure_flags" -Value "$configure_flags --with-intl=none"}
    if ($i18n_arg -eq "without-intl"){Set-Variable -Name "configure_flags" -Value "$configure_flags --without-intl"}

    if ($config_flags -ne $null){Set-Variable -Name "configure_flags" -Value "$configure_flags $config_flags"}

    if (-Not (Test-Path $(-join($scriptRoot, "\deps\icu")))) {NoDepsICU}
    if ($target -eq "Clean"){echo "deleting $scriptRoot + \deps\icu"; Remove-Item $(-join($scriptRoot, "\deps\icu")) -Force -Recurse}

}

AssignPathToNode_exe

function ArgOK {
    shift
    NextArg
}

function NextArg {

    if ($($args[1]) -eq $null){ArgsDone}
    if ($($args[1]) -eq "debug"){Set-Variable -Name "config" -Value "Debug"; ArgOK}
    if ($($args[1]) -eq "release"){Set-Variable -Name "config" -Value "Release"; ArgOK}
    if ($($args[1]) -eq "clean"){Set-Variable -Name "target" -Value "Clean"; ArgOK}
    if ($($args[1]) -eq "ia32"){Set-Variable -Name "target_arch" -Value "x86"; ArgOK}
    if ($($args[1]) -eq "x86"){Set-Variable -Name "target_arch" -Value "x86"; ArgOK}
    if ($($args[1]) -eq "x64"){Set-Variable -Name "target_arch" -Value "x64"; ArgOK}
    echo "args should be vs2017 and vs2015. keeping vc2015 for backward compatibility (undocumented)"
    if ($($args[1]) -eq "vc2015"){Set-Variable -Name "target_env" -Value "vs2015"; ArgOK}
    if ($($args[1]) -eq "vs2015"){Set-Variable -Name "target_env" -Value "vs2015"; ArgOK}
    if ($($args[1]) -eq "vs2017"){Set-Variable -Name "target_env" -Value "vs2017"; ArgOK}
    if ($($args[1]) -eq "noprojgen"){Set-Variable -Name "noprojgen" -Value "1"; ArgOK}
    if ($($args[1]) -eq "nobuild"){Set-Variable -Name "nobuild" -Value "1"; ArgOK}
    if ($($args[1]) -eq "nosign"){Set-Variable -Name "sign"; echo "Note: vcbuild no longer signs by default. 'nosign' is redundant."; ArgOK}
    if ($($args[1]) -eq "sign"){Set-Variable -Name "sign" -Value "1"; ArgOK}
    if ($($args[1]) -eq "nosnapshot"){Set-Variable -Name "nosnapshot" -Value "1"; ArgOK}
    if ($($args[1]) -eq "noetw"){Set-Variable -Name "noetw" -Value "1"; ArgOK}
    if ($($args[1]) -eq "noperfctr"){Set-Variable -Name "noperfctr" -Value "1"; ArgOK}
    if ($($args[1]) -eq "licensertf"){Set-Variable -Name "licensertf" -Value "1"; ArgOK}
    if ($($args[1]) -eq "test"){Set-Variable -Name "test_args" -Value "-J $common_test_suites"; Set-Variable -Name "cpplint" -Value "1"; Set-Variable -Name "jslint" -Value "1"; ArgOK}
    if ($($args[1]) -eq "test-ci"){Set-Variable -Name "test_args" -Value "$test_args $test_ci_args -p tap  --logfile test.tap $common_test_suites"; Set-Variable -Name "cctest_args" -Value "$cctest_args -gtest_output=tap:cctest.tap"; Set-Variable -Name "jslint" -Value "1"; ArgOK}
    if ($($args[1]) -eq "addons"){Set-Variable -Name "test_args" -Value "$test_args addons"; Set-Variable -Name "build_addons" -Value "1"; ArgOK}
    if ($($args[1]) -eq "addons-napi"){Set-Variable -Name "test_args" -Value "$test_args addons-napi"; Set-Variable -Name "build_addons_napi" -Value "1"; ArgOK}
    if ($($args[1]) -eq "test-simple"){Set-Variable -Name "test_args" -Value "$test_args sequential parallel -J"; ArgOK}
    if ($($args[1]) -eq "test-message"){Set-Variable -Name "test_args" -Value "$test_args message"; ArgOK}
    if ($($args[1]) -eq "test-gc"){Set-Variable -Name "test_args" -Value "$test_args gc"; Set-Variable -Name "build_testgc_addon" -Value "1"; ArgOK}
    if ($($args[1]) -eq "test-inspector"){Set-Variable -Name "test_args" -Value "$test_args inspector"; ArgOK}
    if ($($args[1]) -eq "test-tick-processor"){Set-Variable -Name "test_args" -Value "$test_args tick-processor"; ArgOK}
    if ($($args[1]) -eq "test-internet"){Set-Variable -Name "test_args" -Value "$test_args internet"; ArgOK}
    if ($($args[1]) -eq "test-pummel"){Set-Variable -Name "test_args" -Value "$test_args pummel"; ArgOK}
    if ($($args[1]) -eq "test-known-issues"){Set-Variable -Name "test_args" -Value "$test_args known_issues"; ArgOK}
    if ($($args[1]) -eq "test-async-hooks"){Set-Variable -Name "test_args" -Value "$test_args async-hooks"; ArgOK}
    if ($($args[1]) -eq "test-all"){Set-Variable -Name "test_args" -Value "$test_args gc internet pummel $common_test_suites"; Set-Variable -Name "build_testgc_addon" -Value "1"; Set-Variable -Name "cpplint" -Value "1"; Set-Variable -Name "jslint" -Value "1";  ArgOK}
    if ($($args[1]) -eq "test-node-inspect"){Set-Variable -Name "test_node_inspect" -Value "1"; ArgOK}
    if ($($args[1]) -eq "test-check-deopts"){Set-Variable -Name "test_check_deopts" -Value "1"; ArgOK}
    if ($($args[1]) -eq "jslint"){Set-Variable -Name "jslint" -Value "1"; ArgOK}
    if ($($args[1]) -eq "jslint-ci"){Set-Variable -Name "jslint_ci" -Value "1"; ArgOK}
    if ($($args[1]) -eq "lint"){Set-Variable -Name "cpplint" -Value "1"; Set-Variable -Name "jslint" -Value "1"; ArgOK}
    if ($($args[1]) -eq "lint-ci"){Set-Variable -Name "cpplint" -Value "1"; Set-Variable -Name "jslint_ci" -Value "1"; ArgOK}
    if ($($args[1]) -eq "package"){Set-Variable -Name "package" -Value "1"; ArgOK}
    if ($($args[1]) -eq "msi"){Set-Variable -Name "msi" -Value "1"; Set-Variable -Name "licensertf" -Value "1"; Set-Variable -Name "download_arg" -Value "--download=all"; Set-Variable -Name "i18n_arg" -Value "small-icu"; ArgOK}
    if ($($args[1]) -eq "build-release"){Set-Variable -Name "build-release" -Value "1"; Set-Variable -Name "sign" -Value "1"; ArgOK}
    if ($($args[1]) -eq "upload"){Set-Variable -Name "upload" -Value "1"; ArgOK}
    if ($($args[1]) -eq "small-icu"){Set-Variable -Name "i18n_arg" -Value "$($args[1])"; ArgOK}
    if ($($args[1]) -eq "full-icu"){Set-Variable -Name "i18n_arg" -Value "$($args[1])"; ArgOK}
    if ($($args[1]) -eq "intl-none"){Set-Variable -Name "i18n_arg" -Value "$($args[1])"; ArgOK}
    if ($($args[1]) -eq "without-intl"){Set-Variable -Name "i18n_arg" -Value "$($args[1])"; ArgOK}
    if ($($args[1]) -eq "download-all"){Set-Variable -Name "download_arg" -Value "--download=all"; ArgOK}
    if ($($args[1]) -eq "ignore-flaky"){Set-Variable -Name "test_args" -Value "--flaky-tests=dontcare"; ArgOK}
    if ($($args[1]) -eq "enable-vtune"){Set-Variable -Name "enable_vtune_arg" -Value "1"; ArgOK}
    if ($($args[1]) -eq "dll"){Set-Variable -Name "dll" -Value "1"; ArgOK}
    if ($($args[1]) -eq "static"){Set-Variable -Name "enable_static" -Value "1"; ArgOK}
    if ($($args[1]) -eq "no-NODE-OPTIONS"){Set-Variable -Name "no_NODE_OPTIONS" -Value "1"; ArgOK}
    echo "Error: invalid command line option '$($($args[1]))'."
    exit 1
}
exit
