#Region Internal

// Gets a predefined exchange plan node.
//
// Parameters:
//  ExchangePlan - ExchangePlanRef - reference to to exchange plan.
// 
// Returns:
//  Boolean - exchange node predefined or not.
//
Function GetThisExchangePlanNode(Val ExchangePlan) Export
	
	Return (ExchangePlan = ExchangePlans.Website.ThisNode());
	
EndFunction

Function NodeArrayForRegistration(ProductsExchange = False, OrdersExchange = False) Export
	
	NodeArray = New Array;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WebsiteExchangePlan.Ref AS Node
	|FROM
	|	ExchangePlan.Website AS WebsiteExchangePlan
	|WHERE
	|	CASE
	|			WHEN &ProductsExchange
	|				THEN WebsiteExchangePlan.ExportProducts
	|			WHEN &OrdersExchange
	|				THEN WebsiteExchangePlan.ImportOrders
	|		END
	|	AND NOT WebsiteExchangePlan.Ref = &ThisNode";
	Query.SetParameter("ProductsExchange", ProductsExchange);
	Query.SetParameter("OrdersExchange", OrdersExchange);
	Query.SetParameter("ThisNode", ExchangePlans.Website.ThisNode());
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		NodeArray.Add(Selection.Node);
	EndDo;
	
	Return NodeArray;
	
EndFunction

#EndRegion