@echo off
setlocal
pushd "%~dp0.." || exit /b 1

cjpm build || goto :failed
cjpm test || goto :failed
cd example || goto :failed
cjpm run || goto :failed

popd
exit /b 0

:failed
popd
exit /b 1
