@ECHO OFF
SETLOCAL enabledelayedexpansion

rem This script will walk you through creating a wallet for your stakepool on the Apex Fusion Prime TESTNET (not mainnet).
rem This script does not send any information to Crypto Blocks or any other third party. Feel free to upload this script
rem to Bing Copilot in the Edge browser or ChatGPT and ask it to explain the script to you. It is safe to do so. You can 
rem also pointedly ask it to check if the script sends any information to any third party. 

rem Notify the user which Apex Fusion network they are creating a wallet for
echo This script will walk you through creating a wallet for your stakepool on the Apex Fusion Prime TESTNET (not mainnet).
echo Do not continue if you are trying to setup a wallet for Apex Fusion Prime MAINNET (not testnet).
echo.
choice /C YN /M "Do you want to continue with wallet creation for the Apex Fusion Prime TESTNET?"
IF ERRORLEVEL 2 exit /b

rem Check if a wallet name was provided as an argument, and if not, prompt the user for one
IF "%~1"=="" (
    echo No wallet name provided.
    set /p "walletName=Please enter the name of the wallet (use your stakepool ticker or name, with no spaces): "
    GOTO walletNameSet
) ELSE (
    set "walletName=%~1"
)

rem Set the wallet name
:walletNameSet
echo Generating a wallet for %walletName%
echo.

rem Check if wallet files already exist
dir /b | findstr /b "%walletName%" >nul 2>&1
IF %ERRORLEVEL% EQU 1 (
    echo No files starting with %walletName% found.
) ELSE (
    echo +***********************************************************************************************************+
    echo Existing files starting with %walletName% found.
    echo WARNING: If you continue, the mnemonic key word phrase and all generated files will be permanently overwritten.
    echo Is this what you intended?
    echo. 
    echo If you are creating a multi-owner pool and/or have a separate reward wallet from the owner wallet, cancel
    echo this script and use a different wallet name for the new wallet. Each wallet must have a unique name if you need
    echo more than one wallet. For example "TICKR-pledge1", "TICKR-pledge2", "TICKR-reward", etc. DO NOT use the same
    echo wallet name for multiple wallets as this will cause conflicts and errors.
    echo.
    echo Are you sure you want to overwrite these files?
    echo +***********************************************************************************************************+
    choice /C YN /M "Press Y to overwrite, N to cancel"
    IF ERRORLEVEL 2 (
        echo Please run again with a different wallet name or delete all of the files with the current wallet name if you want to try again.
        exit /b
    )
)

rem clear the screen for less clutter
cls

rem Define the source URLs
SET cardanoNodeSource=https://github.com/IntersectMBO/cardano-node/releases/download/8.9.3/cardano-node-8.9.3-win64.zip
SET cardanoAddressSource=https://github.com/IntersectMBO/cardano-addresses/releases/download/3.12.0/cardano-addresses-3.12.0-win64.zip

rem Define the directories where the extracted files should be extracted to
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

rem Check if the Cardano CLI file exists
echo Checking for Cardano CLI file...
IF NOT EXIST %CARDANO_CLI% (
    echo Cardano CLI not found.
    rem Check if the Cardano Node source zip file exists
    echo Checking for Cardano Node source zip file...
    IF NOT EXIST cardano-node.zip (
        rem Download the Cardano Node source
        echo Downloading the Cardano Node source...
        curl -L -o cardano-node.zip %cardanoNodeSource%
    )
    rem Extract the zip file
    echo Extracting the Cardano Node...
    tar -xf cardano-node.zip -C %cardanoNodeDir%
)

rem Check if the Bech32 file exists
echo Checking for Bech32 file...
IF NOT EXIST %BECH32% (
    echo Bech32 not found.
    rem Check if the Cardano Node source zip file exists
    echo Checking for Cardano Node source zip file...
    IF NOT EXIST cardano-node.zip (
        rem Download the Cardano Node source
        echo Downloading the Cardano Node source...
        curl -L -o cardano-node.zip %cardanoNodeSource%
    )
    rem Extract the zip file
    echo Extracting the Cardano Node...
    tar -xf cardano-node.zip -C %cardanoNodeDir%
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
    )
    rem Extract the zip file
    echo Extracting the Cardano Address file...
    tar -xf cardano-address.zip -C %cardanoAddressDir%
)

rem Generate mnemonic phrase
%CARDANO_ADDRESS% recovery-phrase generate --size 24 > %walletName%.mnemonic.txt

rem Get root private key from mnemonic phrase
type %walletName%.mnemonic.txt | %CARDANO_ADDRESS% key from-recovery-phrase Shelley > %walletName%.root.prv

rem Derive stake key from root private key
type %walletName%.root.prv | %CARDANO_ADDRESS% key child 1852H/1815H/0H/2/0 > %walletName%.stake.xprv

rem Retrieve stake public key from stake private key
type %walletName%.stake.xprv | %CARDANO_ADDRESS% key public --with-chain-code > %walletName%.stake.xpub

rem Derive payment key from root private key
type %walletName%.root.prv | %CARDANO_ADDRESS% key child 1852H/1815H/0H/0/0 > %walletName%.payment.xprv

rem Retrieve payment public key from payment private key
type %walletName%.payment.xprv | %CARDANO_ADDRESS% key public --with-chain-code > %walletName%.payment.xpub

rem Get payment address
type %walletName%.payment.xpub | %CARDANO_ADDRESS% address payment --network-tag 0 > %walletName%.payment.addr_candidate

rem Calculate a payment.addr candidate to match at the end
set /p stake.xpub= < %walletName%.stake.xpub

rem Calculate a base.addr candidate to match at the end
type %walletName%.payment.addr_candidate | %CARDANO_ADDRESS% address delegation %stake.xpub% > %walletName%.base.addr_candidate

rem Create SESKEY
type %walletName%.stake.xprv | %BECH32% > %walletName%.stake.xprvb32
set /p stake.xprvb32= < %walletName%.stake.xprvb32
type %walletName%.stake.xpub | %BECH32% > %walletName%.stake.xpubb32
set /p stake.xpubb32= < %walletName%.stake.xpubb32
set SESKEY=%stake.xprvb32:~0,128%%stake.xpubb32%

rem Create PESKEY
type %walletName%.payment.xprv | %BECH32% > %walletName%.payment.xprvb32
set /p payment.xprvb32= < %walletName%.payment.xprvb32
type %walletName%.payment.xpub | %BECH32% > %walletName%.payment.xpubb32
set /p payment.xpubb32= < %walletName%.payment.xpubb32
set PESKEY=%payment.xprvb32:~0,128%%payment.xpubb32%

rem Generate stake skey
echo {^"type^": ^"StakeExtendedSigningKeyShelley_ed25519_bip32^", ^"description^": ^"^", ^"cborHex^": ^"5880%SESKEY%^"} > %walletName%.stake.skey

rem Generate payment skey
echo {^"type^": ^"PaymentExtendedSigningKeyShelley_ed25519_bip32^", ^"description^": ^"Payment Signing Key^", ^"cborHex^": ^"5880%PESKEY%^"} > %walletName%.payment.skey

rem Generate the stake and payment signing keys
%CARDANO_CLI% shelley key verification-key --signing-key-file %walletName%.stake.skey --verification-key-file %walletName%.stake.evkey
%CARDANO_CLI% shelley key non-extended-key --extended-verification-key-file %walletName%.stake.evkey --verification-key-file %walletName%.stake.vkey
%CARDANO_CLI% shelley key verification-key --signing-key-file %walletName%.payment.skey --verification-key-file %walletName%.payment.evkey
%CARDANO_CLI% shelley key non-extended-key --extended-verification-key-file %walletName%.payment.evkey --verification-key-file %walletName%.payment.vkey

rem Generate the wallet addresses
%CARDANO_CLI% shelley stake-address build --stake-verification-key-file %walletName%.stake.vkey --testnet-magic 3311 > %walletName%.reward.addr
%CARDANO_CLI% shelley address build --payment-verification-key-file %walletName%.payment.vkey --testnet-magic 3311 > %walletName%.payment.addr
%CARDANO_CLI% shelley address build --payment-verification-key-file %walletName%.payment.vkey --stake-verification-key-file %walletName%.stake.vkey --testnet-magic 3311 > %walletName%.base.addr

rem Display the payment address and base address candidates and ask the user to confirm that they match
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
echo Do the addresses match?
choice /C YN /M "Press Y if they match, N if they don't"
IF ERRORLEVEL 2 (
    echo Please take a screenshot and send to admin@cryptoblock.pro for help troubleshooting.
    exit /b
)
rem clear the screen for less clutter
cls

rem Display the base address and base address candidates and ask the user to confirm that they match
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
echo Do the addresses match?
choice /C YN /M "Press Y if they match, N if they don't"
IF ERRORLEVEL 2 (
    echo Please take a screenshot and send to admin@cryptoblock.pro for help troubleshooting.
    exit /b
)
rem clear the screen for less clutter
cls

rem Provide the user with the mnemonic phrase and instructions on how to upload the wallet files and some additional information
echo:
echo Congratulations. Wallet is created.
echo Wallet mnemonic phrase (it is also in the script folder as %walletName%.mnemonic.txt): 
echo +-----------------------------------------------------------------------------------------------------------+
type %walletName%.mnemonic.txt
echo:
echo WARNING: Please safely record this phrase and DO NOT reveal it to anyone.
echo This phrase is the only way to recover your wallet if you lose access to it.
echo Losing this phrase is like losing your wallet keys - you will not be able to recover your wallet.
echo And, it goes without saying, DO NOT share this phrase with anyone, including Crypto Blocks.
echo +-----------------------------------------------------------------------------------------------------------+
echo:
echo We will provide a link to a secure upload portal where you can upload the following files. If you have questions, you can email us at admin@cryptoblocks.pro or message us in our Discord server "apex-sp-hosting" channel at https://discord.com/channels/1247940142178762954/1247948945209032796. The following four files are the minum files required to register the wallet as a stakepool owner wallet, and it DOES NOT give access to spend or send your funds.
echo +-----------------------------------------------------------------------------------------------------------+
echo - %walletName%.base.addr - Your wallet address. Allows Cryptoblocks to monitor the wallet to ensure it contains enough pledge. This is also the place where rewards can be paid out to.
echo - %walletName%.reward.addr - Staking address that gets registered on the blockchain so it can be used as pledge.
echo - %walletName%.stake.skey - The key used to sign the pool certificate and delegate to the pool.
echo - %walletName%.stake.vkey - The public staking key
echo +-----------------------------------------------------------------------------------------------------------+
echo: 
echo We recommend you encrypt or otherwise store the files generated in this directory (everything starting with "%walletName%") securely in case something is needed in the future. The %walletName%.payment.skey can be used to send APEX out of your wallet, so treat it like the mnemonic phrase.
echo:

ENDLOCAL