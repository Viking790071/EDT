
#Region Public

Function GetAdditionalParameterType(ParameterName) Export

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	AdditionalAttributesAndInfo.Ref AS Ref
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|WHERE
	|	AdditionalAttributesAndInfo.Name = &Name";
	
	Query.SetParameter("Name", ParameterName);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Return SelectionDetailRecords.Ref;
	EndIf;	

EndFunction 

Function IsReference(CurrentData) Export
	
	Return Common.IsReference(TypeOf(CurrentData));
	
EndFunction

Procedure CheckDefaultAccountValidation(Val CheckingObject, ErrorFields = Undefined) Export
	
	WorkWithArbitraryParameters.CheckDefaultAccountValidation(CheckingObject, ErrorFields);
	
EndProcedure

Procedure CheckAccountsValueValidation(Val CheckingObject, ErrorFields = Undefined, Cancel = False) Export
	
	WorkWithArbitraryParameters.CheckAccountsValueValidation(CheckingObject, ErrorFields, Cancel);
	
EndProcedure

Function GetChartsOfAccountsData(ChartsOfAccounts) Export
	
	If ValueIsFilled(ChartsOfAccounts) Then
		Return Common.ObjectAttributesValues(ChartsOfAccounts, "UseAnalyticalDimensions, UseQuantity");
	Else 
		Return New Structure("UseAnalyticalDimensions, UseQuantity", False, False);
	EndIf;
	
EndFunction

Procedure CheckAccountsValueChartOfAccountsValidation(Val CheckingObject, ErrorFields = Undefined) Export
	
	WorkWithArbitraryParameters.CheckAccountsValueChartOfAccountsValidation(CheckingObject, ErrorFields);
	
EndProcedure

Function MaxAnalyticalDimensionsNumber() Export
	
	Return ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	
EndFunction

#EndRegion