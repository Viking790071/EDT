
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	List.Parameters.SetParameterValue("EmptyCompany"			, Catalogs.Companies.EmptyRef());
	
	If Parameters.Property("Company") Then
		List.Parameters.SetParameterValue("AllCompanies"		, False);
		List.Parameters.SetParameterValue("Company"				, Parameters.Company);
	Else
		List.Parameters.SetParameterValue("AllCompanies"		, True);
		List.Parameters.SetParameterValue("Company"				, Catalogs.Companies.EmptyRef());
	EndIf;
	
	If Parameters.Property("TypeOfAccounting") Then
		List.Parameters.SetParameterValue("AllTypesOfAccounting", False);
		List.Parameters.SetParameterValue("TypeOfAccounting"	, Parameters.TypeOfAccounting);
	Else
		List.Parameters.SetParameterValue("AllTypesOfAccounting", True);
		List.Parameters.SetParameterValue("TypeOfAccounting"	, Catalogs.TypesOfAccounting.EmptyRef());
	EndIf;
	
	If Parameters.Property("ChartOfAccounts") Then
		List.Parameters.SetParameterValue("AllChartsOfAccounts"	, False);
		List.Parameters.SetParameterValue("ChartOfAccounts"		, Parameters.ChartOfAccounts);
	Else
		List.Parameters.SetParameterValue("AllChartsOfAccounts"	, True);
		List.Parameters.SetParameterValue("ChartOfAccounts"		, Catalogs.ChartsOfAccounts.EmptyRef());
	EndIf;
	
EndProcedure

#EndRegion