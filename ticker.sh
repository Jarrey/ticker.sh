#!/bin/bash
set -e

LANG=C
LC_NUMERIC=C

SYMBOLS=("$@")

if ! $(type jq > /dev/null 2>&1); then
  echo "'jq' is not in the PATH. (See: https://stedolan.github.io/jq/)"
  exit 1
fi

if [ -z "$SYMBOLS" ]; then
  echo "Usage: ./ticker.sh AAPL MSFT GOOG BTC-USD"
  exit
fi

FIELDS=(symbol exchange currency marketState ask bid regularMarketPrice regularMarketChange regularMarketChangePercent \
  preMarketPrice preMarketChange preMarketChangePercent postMarketPrice postMarketChange postMarketChangePercent shortName longName)
API_ENDPOINT="https://query1.finance.yahoo.com/v7/finance/quote?lang=en-US&region=US&corsDomain=finance.yahoo.com"

if [ -z "$NO_COLOR" ]; then
  : "${COLOR_BOLD:=\e[1;37m}"
  : "${COLOR_DOWN:=\e[31m}"
  : "${COLOR_UP:=\e[32m}"
  : "${COLOR_RESET:=\e[00m}"
fi

symbols=$(IFS=,; echo "${SYMBOLS[*]}")
fields=$(IFS=,; echo "${FIELDS[*]}")

results=$(curl --silent "$API_ENDPOINT&fields=$fields&symbols=$symbols" \
  | jq '.quoteResponse .result')

query () {
  echo $results | jq -r ".[] | select(.symbol == \"$1\") | .$2"
}

printf "%-32s%-10s%-20s%-11s%-14s%-16s%-12s%-10s%s\n" "Name" "Exchange" "Symbol" "Price" "Change" "Percent" "Ask" "Bid" "Currency"
printf "%0.s-" {1..133}
printf "\n"
for symbol in $(IFS=' '; echo "${SYMBOLS[*]}"); do
  marketState="$(query $symbol 'marketState')"
  shortName="$(query $symbol 'shortName')"
  exchange="$(query $symbol 'exchange')"
  currency="$(query $symbol 'currency')"

  if [ -z $marketState ]; then
    printf 'No results for symbol "%s"\n' $symbol
    continue
  fi

  preMarketChange="$(query $symbol 'preMarketChange')"
  postMarketChange="$(query $symbol 'postMarketChange')"

  if [ $marketState == "PRE" ] \
    && [ $preMarketChange != "0" ] \
    && [ $preMarketChange != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'preMarketPrice')
    diff=$preMarketChange
    percent=$(query $symbol 'preMarketChangePercent')
  elif [ $marketState != "REGULAR" ] \
    && [ $postMarketChange != "0" ] \
    && [ $postMarketChange != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'postMarketPrice')
    diff=$postMarketChange
    percent=$(query $symbol 'postMarketChangePercent')
  else
    nonRegularMarketSign=''
    price=$(query $symbol 'regularMarketPrice')
    diff=$(query $symbol 'regularMarketChange')
    percent=$(query $symbol 'regularMarketChangePercent')
  fi

  ask=$(query $symbol 'ask')
  bid=$(query $symbol 'bid')

  if [ "$diff" == "0" ]; then
    color=
  elif ( echo "$diff" | grep -q ^- ); then
    color=$COLOR_UP
  else
    color=$COLOR_DOWN
  fi

  printf "%-32s" "$shortName"
  printf "%-10s%-15s$COLOR_BOLD%10.4f$COLOR_RESET" $exchange $symbol $price
  printf "$color%12.4f%15s%12.4f%12.4f$COLOR_RESET%10s" $diff $(printf "(%.4f%%)" $percent) $ask $bid $currency
  printf " %s\n" "$nonRegularMarketSign"
done
