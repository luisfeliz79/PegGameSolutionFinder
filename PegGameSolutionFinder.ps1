#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
$Trail=""
$Plays=@()
$Instances=0
$Global:NoOfMoves=0

function BetterWrite-Progress ($Activity, $Status){

$CurrentCharWidth=$host.ui.RawUI.BufferSize.Width
$statusArr=$Status -split "`n"

$NewStatus=$StatusArr | %{

    $Line=$_.trim()

    if ($line.length -lt $CurrentCharWidth) {

        "$line $(" "* ($CurrentCharWidth - $line.length))" 

    }

} | out-string

Write-Progress -Activity $Activity -Status $NewStatus

}

function MoveLeft ($Position,$Array) {


$origPos=$position
$origArr=$Array



if ($Position -eq 0) {$Position = $Array.count -1;$More="Fixed"}

    $Current=$Array[$Position]
    $Pre=$Array[$Position-1]
    $Array[$Position]=$Pre
    $Array[$Position-1]=$Current

#"Outgoing: $Array [$Position] Incoming: $OrigArr [$position] $More"

}


#Provides the initial state of the board
Function NewGameBoard {

$Arr1=@(1)
$Arr2=@(1,1)
$Arr3=@(1,0,1)
$Arr4=@(1,1,1,1)
$Arr5=@(1,1,1,1,1)

$GameBoardArray= @($Arr1,$Arr2,$Arr3,$Arr4,$Arr5)

$GameBoardArray

}

#Special function to copy Gameboards as PowerShell treats ArrayLists as References when being passed as a parameter
Function CopyGameBoard ($Gameboard) {

$cpyArray=@()

0..15 | % {

    switch ($Gameboard[$_]) {
    
        0 { $cpyArray+=0 }
        1 { $cpyArray+=1 }        

    }
}

$Arr1=@($cpyArray[0])
$Arr2=@($cpyArray[1],$cpyArray[2])
$Arr3=@($cpyArray[3],$cpyArray[4],$cpyArray[5])
$Arr4=@($cpyArray[6],$cpyArray[7],$cpyArray[8],$cpyArray[9])
$Arr5=@($cpyArray[10],$cpyArray[11],$cpyArray[12],$cpyArray[13],$cpyArray[14])

$CpyGBArray= @($Arr1,$Arr2,$Arr3,$Arr4,$Arr5)

$CpyGBArray

}

#Used for making a out a pretty Gameboard
Function CenteredPieces ($String) {
$Max=10
$FixedString=""

$StringLen=$string.Length

0..($StringLen-1) | foreach { $Fixedstring+="$($String[$_]) "}
$StringLen=$Fixedstring.Length



$Spaces=($Max-$StringLen)/2


$PaddedPieces = $(" "*$Spaces)+$FixedString+$(" "*$Spaces)    

return $paddedPieces

}



#Prints out a pretty gameboard
function PrintGameBoard ($Gameboard) {

$GameBoard | % {
    $Pieces=""
    $_ | %{

        $Pieces+=if ($_ -eq 0) { "o" } else { "*" }

    }
    
    CenteredPieces $Pieces


}
}

#Checks how many pegs are left on the board
Function CheckRemainingPieces ($GameBoard) {
$Count=0
$GameBoard | % {

    $_ | %{

        if ($_ -eq 1) { $Count++ }

    }
}

return $Count

} 



#Provides current state and information about each Peg position
Function Piece ($who, $GameBoard) {

    switch ($who) {

    1 {$x=0;$y=0;$targets=@{2=4;3=6} }
    2 {$x=1;$y=0;$targets=@{4=7;5=9} }
    3 {$x=1;$y=1;$targets=@{5=8;6=10} }
    4 {$x=2;$y=0;$targets=@{2=1;5=6;7=11;8=13} }
    5 {$x=2;$y=1;$targets=@{8=12;9=14} }
    6 {$x=2;$y=2;$targets=@{3=1;5=4;9=13;10=15} }
    7 {$x=3;$y=0;$targets=@{4=2;8=9} }
    8 {$x=3;$y=1;$targets=@{5=3;9=10} }
    9 {$x=3;$y=2;$targets=@{5=2;8=7} }
    10 {$x=3;$y=3;$targets=@{6=3;9=8} }
    11 {$x=4;$y=0;$targets=@{7=4;12=13} }
    12 {$x=4;$y=1;$targets=@{8=5;13=14} }
    13 {$x=4;$y=2;$targets=@{8=4;9=6;12=11;14=15} }
    14 {$x=4;$y=3;$targets=@{13=12;9=5} }
    15 {$x=4;$y=4;$targets=@{10=6;14=13} }

    }
 

 try {
    return @{Status=$GameBoard[$x][$y];Targets=$targets;x=$x;y=$y}
    }

    catch {
    "error"
    }
}

#Sets the peg status
Function SetPieceStatus ($who,$status,$GameBoard) {


    $PieceInfo=piece -who $who -GameBoard $GameBoard
    $GameBoard[$PieceInfo.x][$PieceInfo.y]=$status

    
}

#Finds possible moves for a Peg
Function FindMove ($who, $GameBoard) {

$AllMoves=@{}
$Piece=piece -who $who -GameBoard $GameBoard

    if ($piece.status) {
        #if the peg is there continue

        $piece.targets.getenumerator() | %{


            $PossibleMove=$_
            #go through each possible move for this peg
            $jumppegStatus=(piece -who $_.Name -Gameboard $Gameboard).status
            $landingspotstatus=(piece -who $_.Value -Gameboard $Gameboard).status
            if ($jumppegstatus) {
            #If present, thats good, now lets check if landing spot is empty
            
                if ($landingSpotStatus -eq 0) {  
                    #we are good, mark it as a possible move

                    $Possiblemove | %{

                        New-Object -TypeName psobject -Property ([ordered]@{
                    
                        who=$who
                        jumped=$_.Name
                        landing=$_.Value
                    
                    })

                    }
                                   
                }


            }

       }

    }
   
}

#Moves a peg on the gameboard
Function MakeAMove ($Move, $GameBoard) {
##write-warning "making move"
$before=@()
$after=@()
$BeforeAndAfter=@()

$before=PrintGameBoard -Gameboard $Gameboard

$Global:NoOfMoves++
    
    $JumpingPeg = $move.who
    $JumpedPeg=$move.jumped
    $LandingSpot=$move.landing

    #Sanity check first
    if ((piece -who $JumpingPeg) -and (piece -who $JumpedPeg -and (-not (piece -who $LandingSpot)))) {

        SetPieceStatus -who $JumpingPeg -status 0 -Gameboard $Gameboard
        SetPieceStatus -who $JumpedPeg -status 0 -Gameboard $Gameboard
        SetPieceStatus -who $LandingSpot -status 1 -Gameboard $Gameboard
    
        $After=PrintGameBoard -Gameboard $Gameboard
    
        0..4 | % { if ($_ -eq 2) {$MoveLabel="$JumpingPeg => $LandingSpot";$MoveLabel+=" "*(8-$MoveLabel.length);write-output "$($before[$_])      $MoveLabel     $($after[$_])"} else {write-output "$($before[$_])                   $($after[$_])"} } 
    

    } else {

        $JumpingPeg
        $JumpedPeg
        $LandingSpot
        Write-error "Invalid move requested, check your code!";break  

    }



    
   
}


#Function which constantly makes moves until number of pegs equals $goal.
Function PlayTheGame ($GameBoard) {



$Spots=@()
$InstNum=$Instances
$Instances++
#write-warning "=========NEW INSTANCE $InstNum========="
$private:CurrentGB=CopyGameBoard -Gameboard $GameBoard

1..15 | % {$Spots+=$_}

$Local:AllMoves=$Spots | % {

    ##write-warning $_
    $CurrentSpot=$_
    Findmove -who $CurrentSpot -GameBoard $private:CurrentGB
    
}



if ($Local:AllMoves) {

if ($InstNum -eq 0) {
#Allow the user to choose the opening move


write-host "`n"
write-host "Do you have a preferred Opening move [1-$($Local:AllMoves.count)]"
$MoveChoice=0
$Local:AllMoves | %{

    $MoveChoice++
    write-host "    $MoveChoice) PEG: $($_.who) to SPOT: $($_.landing) "

}
write-host "`n"
$Local:OpeningMove=read-host -Prompt "Default is 1"
$Local:OpeningMove=[int]$Local:OpeningMove

    if ($Local:OpeningMove) {

        if ($Local:OpeningMove -gt 0 -and $Local:OpeningMove -le $Local:AllMoves.count) {

            $Local:AllMoves=$Local:AllMoves[$Local:OpeningMove-1]
        
        } else { "Invalid Input... quitting";break }

    }
    write-host "Using PEG: $($local:allmoves.who) to SPOT: $($local:allmoves.landing) "
    write-host "`n"
    $Global:StartTime=get-date    
    "Started: $($Global:StartTime)"
}



    #write-warning "Processing $($Local:AllMoves.count) moves"
    $Local:AllMoves | % {
                #write-warning "Instance$InstNum"       


                $Local:Counter++
                #write-warning "Making Move $Local:Counter"
                if ($local:counter -gt 1 ){
                    #write-warning "NEW PATH"
                }
                 
                
                #Backup Current Trail and Plays
                $Local:HoldTrail=$Trail
                $Local:HoldPlays=$Plays


                $Trail+="$($_.who)=>$($_.Landing),"

                
                $private:tmpholdGB = CopyGameBoard -Gameboard $private:CurrentGB
                    
                $result=MakeAMove -Move $_ -GameBoard $private:CurrentGB

                ######## scrolling output or progressbar
                #
                $CurrentCurPos=$host.ui.RawUI.CursorPosition
                
                $result
                
                $host.ui.RawUI.CursorPosition =$CurrentCurPos
               

                #BetterWrite-Progress -Activity "Solving for x of x and y`nSecondLIne" -Status "$($result | out-string)`nSecond Line aflkas;dfka;sdkf;aslkf;aslfsadfasfdasdfasdfasdfasdfasdfasdfasdfasdfasdfsadfsafsadf"  

                $Remain=CheckRemainingPieces -GameBoard $private:CurrentGB
            

                $Plays+=$result
                
                $Plays+="Remain: $Remain"

                if ($Remain -eq $Goal) {
                    
                    Write-host "Complete!" -ForegroundColor Cyan
                    write-host "-----------------------------------------------" -ForegroundColor Cyan
                    $Plays
                    Write-host "`n"
                    Write-host "Solution found to goal of $Goal Peg left" -ForegroundColor Cyan
                    write-host "-----------------------------------------------" -ForegroundColor Cyan
                    write-host "PATH: $($Trail.trimend(","))"
                    write-host "Total Moves: $Global:NoOfMoves"
                    write-host "Finished: $(get-date)"
                    
                    ((Get-date)-$global:starttime) 
                    
                    $PlayWav=New-Object System.Media.SoundPlayer
                    $PlayWav.SoundLocation="C:\Windows\Media\Windows Ringin.wav"
                    $PlayWav.playsync()
                    $PlayWav.playsync()
                    $PlayWav.playsync()
                    break
                }
                               
                
                PlayTheGame -GameBoard $private:CurrentGB

                #Prepare for next move
                $private:CurrentGB=CopyGameBoard -Gameboard $private:tmpholdGB
                $Trail=$local:HoldTrail
                $Plays=$local:HoldPlays

    }

} else {
    #write-warning "No Moves Left"
}

}
Function NewGameHeader {

    Clear 

    Write-host "Peg Game Solution Finder - By Luis Feliz" -ForegroundColor Cyan
    write-host "`n"

    PrintGameBoard -Gameboard $MyNewGameBoard | Out-Host

}

Function NewGame() {

NewGameHeader

write-host "`n"
write-host "Change Default Empty Peg? [1-15] "
$EmptyPeg=read-host -Prompt "Currently set to 5"
$EmptyPeg=[int]$EmptyPeg
if ($EmptyPeg) {

    if ($EmptyPeg -gt 0 -and $EmptyPeg -le 15) {

        SetPieceStatus -who ($EmptyPeg) -status 0 -GameBoard $MyNewGameBoard
        SetPieceStatus -who (5) -status 1 -GameBoard $MyNewGameBoard
        NewGameHeader

    } else { "Invalid Input... quitting";break }


}

$Goal=1

write-host "`n"
write-host "Change the Goal? Pegs left: [1-8] "
$PegGoal=read-host -Prompt "Default is 1"
$PegGoal=[int]$PegGoal
if ($PegGoal) {

    if ($PegGoal -ge 1 -and $PegGoal -le 8) {
        $Goal= $PegGoal
        

    } else { "Invalid Input... quitting";break }


}

Return $Goal

}


cls

$Global:StartTime=Get-Date

New-Variable -Name MyNewGameBoard -Value (NewGameBoard) -Option ReadOnly -Visibility public -Scope local -Force

$Goal=NewGame


$Plays+=PrintGameBoard -Gameboard $MyNewGameBoard

PlayTheGame -GameBoard ($MyNewGameBoard)

<#
11=>4
Remain: 1 Instance: Instance12 Move: 1 
10=>3,1=>6,8=>3,3=>10,14=>5,2=>9,7=>2,10=>8,12=>14,15=>13,13=>4,2=>7,11=>4,
Total Moves: 32273

#>

