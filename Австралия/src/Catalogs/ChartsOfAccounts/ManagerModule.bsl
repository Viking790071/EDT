#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function CheckExistAccountsWithAnalyticalDimensionsFlag(Val ChartOfAccounts) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	MasterChartOfAccounts.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts
	|	AND MasterChartOfAccounts.UseAnalyticalDimensions";
	
	Query.SetParameter("ChartOfAccounts", ChartOfAccounts);
	
	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return Not QueryResult.IsEmpty();

EndFunction

Function CheckExistAccountsWithQuantityFlag(Val ChartOfAccounts) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	MasterChartOfAccounts.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts
	|	AND MasterChartOfAccounts.UseQuantity";
	
	Query.SetParameter("ChartOfAccounts", ChartOfAccounts);
	
	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return Not QueryResult.IsEmpty();

EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)

	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ChartsOfAccounts);

EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)

	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);

EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)

	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);

EndProcedure

#EndRegion

#EndIf