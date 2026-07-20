# wallet-scripts

Scripts for Wallet automation with a structure similar to `tedee-scripts`.

## Scripts

- `./setup.sh` - Generate or reconfigure `config/wallet.conf`
- `./bin/update [branch]` - Update scripts from GitHub while preserving config
- `./bin/backup` - Create a wallet backup placeholder (WIP)

## Configuration

`setup.sh` configures:
- `API_TOKEN`
- `BASE_URL` (default: `https://rest.budgetbakers.com/wallet/v1/api`)
- `TELEGRAM_TOKEN`
- `CHAT_ID`
