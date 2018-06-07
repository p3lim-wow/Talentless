Set-Location -Path "$PSScriptRoot\.."

If(-Not (Test-Path -Path "libs")){
	New-Item -ItemType Directory -Path libs
}

If(-Not (Test-Path -Path "libs\LibStub")){
	New-Item -ItemType SymbolicLink -Path "libs" -Name LibStub -Value ..\LibStub
} ElseIf(-Not (((Get-Item -Path "libs\LibStub").Attributes.ToString()) -Match "ReparsePoint")){
	Remove-Item -Path "libs\LibStub"
	New-Item -ItemType SymbolicLink -Path "libs" -Name LibStub -Value ..\LibStub
}

If(-Not (Test-Path -Path "libs\LibDropDown")){
	New-Item -ItemType SymbolicLink -Path "libs" -Name LibDropDown -Value ..\LibDropDown
} ElseIf(-Not (((Get-Item -Path "libs\LibDropDown").Attributes.ToString()) -Match "ReparsePoint")){
	Remove-Item -Path "libs\LibDropDown"
	New-Item -ItemType SymbolicLink -Path "libs" -Name LibDropDown -Value ..\LibDropDown
}
