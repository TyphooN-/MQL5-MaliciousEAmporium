/**=             CommissionGrindr.mq5  (TyphooN's MQL5 Commission Grindr)
 *               Copyright 2023, TyphooN (https://www.marketwizardry.org/)
 *
 * Disclaimer and Licence
 *
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * All trading involves risk. You should have received the risk warnings
 * and terms of use in the README.MD file distributed with this software.
 * See the README.MD file for more information and before using this software.
 *
 **/
#property copyright "Copyright 2024 TyphooN (MarketWizardry.org)"
#property link      "http://marketwizardry.info/"
#property version   "1.004"
#property description "TyphooN's Commission Grindr"
#include <Trade\Trade.mqh>
#include <Orchard\RiskCalc.mqh>
double TotalLotsToSell = 999999999999999;
double LotsTraded = 0.0;
double MaxLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
double MinLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
datetime LastDiscordBroadcastTime = 0;
string LastDiscordAnnouncement = "";
int OrderDigits = 0;
int broadcastCooldown = 1; // Cooldown period in seconds
CTrade Trade; // Create an instance of the trade class
// orchard compat functions
string BaseCurrency() { return ( AccountInfoString( ACCOUNT_CURRENCY ) ); }
double Point( string symbol ) { return ( SymbolInfoDouble( symbol, SYMBOL_POINT ) ); }
double TickSize( string symbol ) { return ( SymbolInfoDouble( symbol, SYMBOL_TRADE_TICK_SIZE ) ); }
double TickValue( string symbol ) { return ( SymbolInfoDouble( symbol, SYMBOL_TRADE_TICK_VALUE ) ); }
int OnInit()
{
   BroadcastAccountInfo();
   if (!CheckTradingConditions())
   {
       Print("Trading conditions not met. EA initialization failed.");
       return(INIT_FAILED);
   }
   Trade.SetAsyncMode(true);
   double volumeStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   // Convert the volume step to a string
   string volumeStepStr = DoubleToString(volumeStep, 8); // 8 decimal places should be enough
   // Find the position of the decimal point
   int decimalPos = StringFind(volumeStepStr, ".");
   // If there is a decimal point, calculate the number of digits after it
   if (decimalPos >= 0)
   {
      // Calculate the number of digits after the decimal point
      OrderDigits = StringLen(volumeStepStr) - decimalPos - 1;
      // Trim trailing zeros to get the exact number of digits
      while (StringSubstr(volumeStepStr, StringLen(volumeStepStr) - 1, 1) == "0")
      {
         volumeStepStr = StringSubstr(volumeStepStr, 0, StringLen(volumeStepStr) - 1);
         OrderDigits--;
      }
   }
   // Print the OrderDigits value
   Print("OrderDigits: ", OrderDigits);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
}
void OnTick()
{
   BroadcastAccountInfo();
    // Calculate the maximum lots to trade based on available margin
    double RiskMoney = (AccountInfoDouble(ACCOUNT_MARGIN_FREE));
    double Lots = NormalizeDouble(RiskLots(_Symbol,RiskMoney,100),OrderDigits);
    // Main loop to sell up to the calculated maxLotsToTrade
    while (LotsTraded < TotalLotsToSell)
    {
      if (!PlaceOrders(Lots))
      {
    //     if (!PlaceOrders(Lots))
     //    {
            Print("Exiting loop due to failed order placement.  Closing all open positions.");
            CloseAllPositionsOnAllSymbols();
            break; // Exit the loop if the order placement fails
         }
      //}
   }
}

void BroadcastAccountInfo()
{
   // Check if the cooldown period has been met
   if (TimeCurrent() - LastDiscordBroadcastTime < broadcastCooldown)
   {
      Print("Cooldown period not met. Skipping broadcast.");
      return;
   }
   // Get account information
   string accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string accountName = AccountInfoString(ACCOUNT_NAME);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string server = AccountInfoString(ACCOUNT_SERVER);
   int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
   // Format the leverage as 1:5, 1:20, etc.
   string leverageFormatted = StringFormat("1:%.0f", leverage);
   string announcement = StringFormat( "[%s] Account #: %s (%s) Balance: %.2f Equity: %.2f Attached Symbol: %s Leverage: %s",
       server, accountNumber, accountName, balance, equity, _Symbol, leverageFormatted);
   // Check if the announcement message is the same as the last one
   if (announcement == LastDiscordAnnouncement)
   {
      Print("Announcement message is the same as the last one. Skipping broadcast.");
      return;
   }

   BroadcastDiscordAnnouncement(announcement);
}
void CloseAllPositionsOnAllSymbols()
{
   Trade.SetAsyncMode(true); // Ensure asynchronous mode is set
   int totalPositions = PositionsTotal();
   if (totalPositions == 0)
   {
      Print("No open positions to close.");
      return;  // No need to proceed if there are no positions
   }
   for (int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i); // Get position ticket number
      double positionVolume = PositionGetDouble(POSITION_VOLUME); // Get position volume
      string symbol = PositionGetString(POSITION_SYMBOL); // Get position symbol
      if (Trade.PositionClose(ticket))
      {
         Print("Closing position ", ticket, " on symbol ", symbol, " with volume ", positionVolume);
      }
      else
      {
         Print("Failed to close position ", ticket, " on symbol ", symbol, ". Error: ", GetLastError());
      }
   }
}
bool PlaceOrders(double lots)
{
   Trade.SetAsyncMode(true);
   double priceBid = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Get the current bid price
   double priceAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Get the current ask price
   double slippage = 20; // Slippage in points
   double stopLoss = 0; // No stop loss
   double takeProfit = 0; // No take profit
   int deviation = (int)slippage; // Slippage as an integer
   bool sellOrderPlaced = false;
   bool buyOrderPlaced = false;
   if (lots < MinLots)
   {
      //Print("Order size adjusted to minimum volume.");
      lots = MinLots;
   }
   if(Trade.Sell(lots, _Symbol, priceBid, stopLoss, takeProfit, "Commission Grindr <3"))
   {
      LotsTraded += lots; // Update the total lots traded
      sellOrderPlaced = true;
   }
   else
   {
      Print("Failed to place sell order. Error: ", GetLastError());
   }
   Print("Attempting to place a buy order at price: ", priceAsk);
   // Try to place a buy order
   if(Trade.Buy(lots, _Symbol, priceAsk, stopLoss, takeProfit, "Commission Grindr <3"))
   {
      LotsTraded += lots; // Update the total lots traded
      buyOrderPlaced = true;
   }
   else
   {
      Print("Failed to place buy order. Error: ", GetLastError());
      CloseAllPositionsOnAllSymbols();
   }
   return sellOrderPlaced && buyOrderPlaced;
}
bool CheckTradingConditions()
{
   if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("Trading is not allowed in the terminal settings.");
      return false;
   }
   
   if (!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("Trading is not allowed for this account.");
      return false;
   }
   return true;
}
void BroadcastDiscordAnnouncement(string announcement)
{
   string DiscordAPIKey = "https://discord.com/api/webhooks/1253433862030229555/GIATaonxr3gJLYs70lMTD6msJm3wmpqhXOUuk0w5WC06r1UQngkIjB6S8Qnr0tiUu6O0";
   string headers = "Content-Type: application/json";
   uchar result[];
   string result_headers;
   string json = "{\"content\":\""+ announcement +"\"}";
   char jsonArray[];
   StringToCharArray(json, jsonArray);
   // Remove null-terminator if any
   int arrSize = ArraySize(jsonArray);
   if(jsonArray[arrSize - 1] == '\0')
   {
      ArrayResize(jsonArray, arrSize - 1);
   }
   int res = WebRequest("POST", DiscordAPIKey, headers, 10, jsonArray, result, result_headers);
   // Get the error immediately after WebRequest
   //int lastError = GetLastError();
   string resultString = CharArrayToString(result);
   //Print("Debug - HTTP response code: ", res);
   //Print("Debug - Result: ", resultString);
   //Print("Debug - JSON as uchar array: ", arrayToString(jsonArray));
   //Print("Debug - Length of Result: ", StringLen(resultString));
   //if(lastError != 0)
   //{
   //   Print("WebRequest Error Code: ", lastError);
   //}
}
