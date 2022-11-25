
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = GetFilterStructure(CommandParameter);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "CreditLimitsByCounterparty");
	FormParameters.Insert("UserSettingsKey", New UUID);
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportVariantsCommandsVisible", False);
	
	OpenForm(
		"Report.CreditLimits.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetFilterStructure(Document)
	
	FilterStructure = New Structure("Company, Counterparty, Contract, Period");
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.Date AS Period
	|FROM
	|	&fromClause AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Document";
	
	fromClause = "Document." + Document.Metadata().Name;
	Query.Text = StrReplace(Query.Text, "&fromClause", fromClause);
	
	Query.SetParameter("Document", Document);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(FilterStructure, Selection); 
	EndIf;
	
	Return FilterStructure;
	
EndFunction

#EndRegion