BeforeAll {
    Import-Module $PSScriptRoot/../../RestSetAcls/Interop.psm1 -Force
}

Describe "Interop" {
    BeforeAll {
        function Test-CreatePrivateObjectSecurityEx {
            param (
                [Parameter(Mandatory = $true)]
                [string]$ParentSddl,

                [Parameter(Mandatory = $true)]
                [string]$ChildSddl,

                [Parameter(Mandatory = $true)]
                [string]$ExpectedSddl,

                [Parameter(Mandatory = $true)]
                [bool]$ChildIsDirectory
            )

            $childFormat = if ($ChildIsDirectory) { "FolderAcl" } else { "FileAcl" }

            $parentDescriptor = Convert-SecurityDescriptor $ParentSddl -From Sddl -To FolderAcl
            $creatorDescriptor = Convert-SecurityDescriptor $ChildSddl -From Sddl -To $childFormat
            
            $result = CreatePrivateObjectSecurityEx `
                -ParentDescriptor $parentDescriptor `
                -CreatorDescriptor $creatorDescriptor `
                -IsDirectory $ChildIsDirectory

            $result | Should -Not -BeNullOrEmpty
            $resultSddl = Convert-SecurityDescriptor $result -From $childFormat -To Sddl
            $reason = "inheritance with parent sddl: $ParentSddl, creator sddl: $ChildSddl is not as expected"
            $resultSddl | Should -Be $ExpectedSddl -Because $reason
        }
    }

    Describe "CreatePrivateObjectSecurityEx" {
        Context "Child is a folder" {
            BeforeAll {
                function Test-Inheritance {
                    param (
                        [Parameter(Mandatory = $true)]
                        [string]$ParentSddl,

                        [Parameter(Mandatory = $true)]
                        [string]$ChildSddl,

                        [Parameter(Mandatory = $true)]
                        [string]$ExpectedSddl
                    )

                    Test-CreatePrivateObjectSecurityEx `
                        -ParentSddl $ParentSddl `
                        -ChildSddl $ChildSddl `
                        -ExpectedSddl $ExpectedSddl `
                        -ChildIsDirectory $true
                }
            }

            It "Just adds AI when there is nothing to inherit in the parent" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)"
            }

            It "Changes nothing when child is already AI and there is nothing to inherit in the parent" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:AI(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)"
            }

            It "Inherits <ParentAceFlags> from parent as <ChildAceFlags>" -ForEach @(
              # OI
              @{ ParentAceFlags = "OI"; ChildAceFlags = "OIIOID" },
              @{ ParentAceFlags = "OIIO"; ChildAceFlags = "OIIOID" },
              @{ ParentAceFlags = "OIID"; ChildAceFlags = "OIIOID" },
              @{ ParentAceFlags = "OIIOID"; ChildAceFlags = "OIIOID" },
              # CI
              @{ ParentAceFlags = "CI"; ChildAceFlags = "CIID" },
              @{ ParentAceFlags = "CIIO"; ChildAceFlags = "CIID" },
              @{ ParentAceFlags = "CIID"; ChildAceFlags = "CIID" },
              @{ ParentAceFlags = "CINP"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "CIIOID"; ChildAceFlags = "CIID" },
              @{ ParentAceFlags = "CINPID"; ChildAceFlags = "ID" },
              # OICI
              @{ ParentAceFlags = "OICI"; ChildAceFlags = "OICIID" },
              @{ ParentAceFlags = "OICIIO"; ChildAceFlags = "OICIID" },
              @{ ParentAceFlags = "OICIID"; ChildAceFlags = "OICIID" },
              @{ ParentAceFlags = "OICIIOID"; ChildAceFlags = "OICIID" },
              @{ ParentAceFlags = "OICINP"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "OICINPID"; ChildAceFlags = "ID" }
            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;$($_.ParentAceFlags);FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)(A;$($_.ChildAceFlags);FA;;;BA)"
            }

            It "Does not inherit <ParentAceFlags> ACEs from parent" -ForEach @(
                @{ ParentAceFlags = "OINP" },
                @{ ParentAceFlags = "OINPID" },
                @{ ParentAceFlags = "OIIONP" },
                @{ ParentAceFlags = "OIIONPID" }
            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;$($_.ParentAceFlags);FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)"
            }

            It "Inherits nothing when parent ACL is '<ParentAclFlags>' and child ACL is '<ChildAclFlags>'" -ForEach @(
                @{ ParentAclFlags = ""; ChildAclFlags = "P" },
                @{ ParentAclFlags = ""; ChildAclFlags = "PAI" },
                @{ ParentAclFlags = "P"; ChildAclFlags = "P" },
                @{ ParentAclFlags = "P"; ChildAclFlags = "PAI" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "P" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "PAI" }
            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:$($_.ParentAclFlags)(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:$($_.ChildAclFlags)(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:P(A;;FA;;;SY)"
            }

            It "Inherits parent ACE when parent ACL is '<ParentAclFlags>' and child ACL is '<ChildAclFlags>'" -ForEach @(
                @{ ParentAclFlags = "P"; ChildAclFlags = "" },
                @{ ParentAclFlags = "P"; ChildAclFlags = "AI" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "AI" }
            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:$($_.ParentAclFlags)(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:$($_.ChildAclFlags)(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)(A;OICIID;FA;;;BA)"
            }

            It "Inherits nothing new if it already has the parent ACE" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;OICI;FA;;;SY)" `
                    -ChildSddl "O:SYG:SYD:(A;OICIID;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;OICIID;FA;;;SY)"
            }

            It "Inherits parent ACEs if it has empty DACL" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;OICIID;FA;;;BA)"
            }

            It "Inherits parent ACEs if it has null DACL" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:NO_ACCESS_CONTROL" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;OICIID;FA;;;BA)"
            }
        }

        Context "Child is a file" {
            BeforeAll {
                function Test-Inheritance {
                    param (
                        [Parameter(Mandatory = $true)]
                        [string]$ParentSddl,

                        [Parameter(Mandatory = $true)]
                        [string]$ChildSddl,

                        [Parameter(Mandatory = $true)]
                        [string]$ExpectedSddl
                    )

                    Test-CreatePrivateObjectSecurityEx `
                        -ParentSddl $ParentSddl `
                        -ChildSddl $ChildSddl `
                        -ExpectedSddl $ExpectedSddl `
                        -ChildIsDirectory $false
                }
            }

            It "Just adds AI when there is nothing to inherit in the parent" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)"
            }

            It "Changes nothing when child is already AI and there is nothing to inherit in the parent" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:AI(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)"
            }

            It "Inherits <ParentAceFlags> from parent as <ChildAceFlags>" -ForEach @(
              # OI
              @{ ParentAceFlags = "OI"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "OIIO"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "OIID"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "OIIOID"; ChildAceFlags = "ID" },
              # OICI
              @{ ParentAceFlags = "OICI"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "OICIIO"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "OICIID"; ChildAceFlags = "ID" },
              @{ ParentAceFlags = "OICIIOID"; ChildAceFlags = "ID" }

            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;$($_.ParentAceFlags);FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)(A;$($_.ChildAceFlags);FA;;;BA)"
            }

            It "Does not inherit <ParentAceFlags> ACEs from parent" -ForEach @(
                # CI
                @{ ParentAceFlags = "CI" },
                @{ ParentAceFlags = "CIIO" },
                @{ ParentAceFlags = "CIID" },
                @{ ParentAceFlags = "CIIOID" }
            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;$($_.ParentAceFlags);FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)"
            }

            It "Inherits nothing when parent ACL is '<ParentAclFlags>' and child ACL is '<ChildAclFlags>'" -ForEach @(
                @{ ParentAclFlags = ""; ChildAclFlags = "P" },
                @{ ParentAclFlags = ""; ChildAclFlags = "PAI" },
                @{ ParentAclFlags = "P"; ChildAclFlags = "P" },
                @{ ParentAclFlags = "P"; ChildAclFlags = "PAI" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "P" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "PAI" }
            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:$($_.ParentAclFlags)(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:$($_.ChildAclFlags)(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:P(A;;FA;;;SY)"
            }

            It "Inherits parent ACE when parent ACL is '<ParentAclFlags>' and child ACL is '<ChildAclFlags>'" -ForEach @(
                @{ ParentAclFlags = "P"; ChildAclFlags = "" },
                @{ ParentAclFlags = "P"; ChildAclFlags = "AI" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "" },
                @{ ParentAclFlags = "PAI"; ChildAclFlags = "AI" }
            ) {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:$($_.ParentAclFlags)(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:$($_.ChildAclFlags)(A;;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;;FA;;;SY)(A;ID;FA;;;BA)"
            }

            It "Inherits nothing new if it already has the parent ACE" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;OICI;FA;;;SY)" `
                    -ChildSddl "O:SYG:SYD:(A;ID;FA;;;SY)" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;ID;FA;;;SY)"
            }

            It "Inherits parent ACEs if it has empty DACL" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;ID;FA;;;BA)"
            }

            It "Inherits parent ACEs if it has null DACL" {
                Test-Inheritance `
                    -ParentSddl "O:BAG:BAD:(A;OICI;FA;;;BA)" `
                    -ChildSddl "O:SYG:SYD:NO_ACCESS_CONTROL" `
                    -ExpectedSddl "O:SYG:SYD:AI(A;ID;FA;;;BA)"
            }
        }
    }
}
