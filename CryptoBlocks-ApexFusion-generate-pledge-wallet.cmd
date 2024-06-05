@ECHO OFF
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
    echo No wallet name provided.
    set /p "walletName=Please enter the name of the wallet (use your stakepool ticker or name, with no spaces): "
    GOTO walletNameSet
) ELSE (
    set "walletName=%~1"
)

:walletNameSet
echo Generating a wallet for %walletName%
echo.

rem Check if wallet files already exist
dir /b | findstr /b "%walletName%" >nul 2>&1
IF %ERRORLEVEL% EQU 1 (
    echo No files starting with %walletName% found.
) ELSE (
    echo Files starting with %walletName% found.
    echo WARNING: If you continue, the mnemonic key word phrase will be permanently overwritten and wallet recovery will be impossible.
    echo Are you sure you want to overwrite these files? [Y/N]
    choice /C YN /M "Press Y to overwrite, N to cancel"
    IF ERRORLEVEL 2 (
        echo Please run again with a different wallet name or delete all of the files with the current wallet name if you want to try again.
        exit /b
    )
)

rem Define the source URLs
SET cardanoNodeSource=https://github.com/IntersectMBO/cardano-node/releases/download/8.9.3/cardano-node-8.9.3-win64.zip
SET cardanoAddressSource=https://github.com/IntersectMBO/cardano-addresses/releases/download/3.12.0/cardano-addresses-3.12.0-win64.zip

rem Define the directories where the extracted files should be
SET cardanoNodeDir=.\cardano-node
SET cardanoAddressDir=.\cardano-address

rem Set the paths to cardano-address.exe, cardano-cli.exe and bech32.exe
set CARDANO_ADDRESS=%cardanoAddressDir%\cardano-address.exe
set CARDANO_CLI=%cardanoNodeDir%\bin\cardano-cli.exe
set BECH32=%cardanoNodeDir%\bin\bech32.exe

rem Create the directories if they don't exist
IF NOT EXIST %cardanoNodeDir% (
    mkdir %cardanoNodeDir%
)
IF NOT EXIST %cardanoAddressDir% (
    mkdir %cardanoAddressDir%
)

rem Check if the Cardano CLI and Bech32 files exist
echo Checking for Cardano CLI and Bech32 files...
IF NOT EXIST %CARDANO_CLI% (
    echo Cardano CLI not found.
    IF NOT EXIST %BECH32% (
        echo Bech32 not found.
        rem Check if the Cardano Node source zip file exists
        echo Checking for Cardano Node source zip file...
        IF NOT EXIST cardano-node.zip (
            rem Download the Cardano Node source
            echo Downloading the Cardano Node source...
            curl -L -o cardano-node.zip %cardanoNodeSource%
            rem Extract the zip file
            tar -xf cardano-node.zip -C %cardanoNodeDir%
        )
    )
)

rem Check if the Cardano Address file exists
echo Checking for Cardano Address file...
IF NOT EXIST %CARDANO_ADDRESS% (
    echo Cardano Address not found.
    rem Check if the Cardano Address source zip file exists
    echo Checking for Cardano Address source zip file...
    IF NOT EXIST cardano-address.zip (
        rem Download the Cardano Address source
        echo Downloading the Cardano Address source...
        curl -L -o cardano-address.zip %cardanoAddressSource%
        rem Extract the zip file
        tar -xf cardano-address.zip -C %cardanoAddressDir%
    )
)

rem Generate mnemonic phrase
%CARDANO_ADDRESS% recovery-phrase generate --size 24 > %walletName%.mnemonic.txt


rem Get root private key from mnemonic phrase
type %walletName%.mnemonic.txt | %CARDANO_ADDRESS% key from-recovery-phrase Shelley > %walletName%.root.prv

rem Derive stake key from root private key
type %walletName%.root.prv | %CARDANO_ADDRESS% key child 1852H/1815H/0H/2/0 > %walletName%.staking.xprv

rem Retrieve stake public key from stake private key
type %walletName%.staking.xprv | %CARDANO_ADDRESS% key public --with-chain-code > %walletName%.staking.xpub

rem Derive payment key from root private key
type %walletName%.root.prv | %CARDANO_ADDRESS% key child 1852H/1815H/0H/0/0 > %walletName%.payment.xprv

rem Retrieve payment public key from payment private key
type %walletName%.payment.xprv | %CARDANO_ADDRESS% key public --with-chain-code > %walletName%.payment.xpub

rem Get payment address
type %walletName%.payment.xpub | %CARDANO_ADDRESS% address payment --network-tag 0 > %walletName%.payment.addr_candidate

set /p staking.xpub= < %walletName%.staking.xpub

rem Calculate a base.addr candidate to match at the end
type %walletName%.payment.addr_candidate | %CARDANO_ADDRESS% address delegation %staking.xpub% > %walletName%.base.addr_candidate

rem Create SESKEY
type %walletName%.staking.xprv | %BECH32% > %walletName%.staking.xprvb32
set /p staking.xprvb32= < %walletName%.staking.xprvb32
type %walletName%.staking.xpub | %BECH32% > %walletName%.staking.xpubb32
set /p staking.xpubb32= < %walletName%.staking.xpubb32
set SESKEY=%staking.xprvb32:~0,128%%staking.xpubb32%

rem Create PESKEY
type %walletName%.payment.xprv | %BECH32% > %walletName%.payment.xprvb32
set /p payment.xprvb32= < %walletName%.payment.xprvb32
type %walletName%.payment.xpub | %BECH32% > %walletName%.payment.xpubb32
set /p payment.xpubb32= < %walletName%.payment.xpubb32
set PESKEY=%payment.xprvb32:~0,128%%payment.xpubb32%

rem Generate staking skey
echo {^"type^": ^"StakeExtendedSigningKeyShelley_ed25519_bip32^", ^"description^": ^"^", ^"cborHex^": ^"5880%SESKEY%^"} > %walletName%.staking.skey

rem Generate payment skey
echo {^"type^": ^"PaymentExtendedSigningKeyShelley_ed25519_bip32^", ^"description^": ^"Payment Signing Key^", ^"cborHex^": ^"5880%PESKEY%^"} > %walletName%.payment.skey

%CARDANO_CLI% shelley key verification-key --signing-key-file %walletName%.staking.skey --verification-key-file %walletName%.staking.evkey
%CARDANO_CLI% shelley key non-extended-key --extended-verification-key-file %walletName%.staking.evkey --verification-key-file %walletName%.staking.vkey
%CARDANO_CLI% shelley key verification-key --signing-key-file %walletName%.payment.skey --verification-key-file %walletName%.payment.evkey
%CARDANO_CLI% shelley key non-extended-key --extended-verification-key-file %walletName%.payment.evkey --verification-key-file %walletName%.payment.vkey

%CARDANO_CLI% shelley stake-address build --stake-verification-key-file %walletName%.staking.vkey --testnet-magic 3311 > %walletName%.staking.addr
%CARDANO_CLI% shelley address build --payment-verification-key-file %walletName%.payment.vkey --testnet-magic 3311 > %walletName%.payment.addr
%CARDANO_CLI% shelley address build --payment-verification-key-file %walletName%.payment.vkey --stake-verification-key-file %walletName%.staking.vkey --testnet-magic 3311 > %walletName%.base.addr

echo.
echo Downloads are complete. Creating wallet...
echo. 
echo The following two addresses must match otherwise things went wrong.
echo +-----------------------------------------------------------------------------------------------------------+
echo %walletName%.payment.addr_candidate
type %walletName%.payment.addr_candidate
echo.
echo %walletName%.payment.addr
type %walletName%.payment.addr
echo.
echo +-----------------------------------------------------------------------------------------------------------+
echo.
echo Do the addresses match? [Y/N]
choice /C YN /M "Press Y if they match, N if they don't"
IF ERRORLEVEL 2 (
    echo Please take a screenshot and send to admin@cryptoblock.pro for help troubleshooting.
    exit /b
)

echo The following two addresses must match otherwise things went wrong.
echo +-----------------------------------------------------------------------------------------------------------+
echo %walletName%.base.addr_candidate
type %walletName%.base.addr_candidate
echo.
echo %walletName%.base.addr
type %walletName%.base.addr
echo.
echo +-----------------------------------------------------------------------------------------------------------+
echo.
echo Do the addresses match? [Y/N]
choice /C YN /M "Press Y if they match, N if they don't"
IF ERRORLEVEL 2 (
    echo Please take a screenshot and send to admin@cryptoblock.pro for help troubleshooting.
    exit /b
)

echo:
echo Congratulations. Wallet is created.
echo Wallet mnemonic phrase (it is also in the script folder as %walletName%.mnemonic.txt): 
echo +-----------------------------------------------------------------------------------------------------------+
type %walletName%.mnemonic.txt
echo:
echo WARNING: Please safely record this phrase and DO NOT reveal it to anyone.
echo This phrase is the only way to recover your wallet if you lose access to it.
echo Losing this phrase is like losing your wallet keys - you will not be able to recover your wallet.
echo +-----------------------------------------------------------------------------------------------------------+
echo:
echo Email these 4 specific files from your desktop folder to admin@cryptoblocks.pro or arrange to send via another means. This is the minum files required to register the wallet as a stake pool owner wallet, and it DOES NOT give access to spend or send funds.
echo +-----------------------------------------------------------------------------------------------------------+
echo - %walletName%.base.addr - Your wallet address. Allows Cryptoblocks to monitor the wallet to ensure it contains enough pledge. This is also the place where rewards can be paid out to.
echo - %walletName%.staking.addr - Staking address that gets registered on the blockchain so it can be used as pledge.
echo - %walletName%.staking.skey - The key used to sign the pool certificate and delegate to the pool.
echo - %walletName%.staking.vkey - The public staking key
echo +-----------------------------------------------------------------------------------------------------------+
echo:

ENDLOCAL