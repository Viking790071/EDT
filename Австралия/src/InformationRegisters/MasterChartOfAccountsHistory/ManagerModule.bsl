#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure SaveAccountHistory(ElemRef, HistoryParameters, NewRef) Export

	SetPrivilegedMode(True);
	
	AttributesList = "StartDate, EndDate, UseQuantity, UseAnalyticalDimensions, AnalyticalDimensionsSet";
	
	If Not NewRef Then
		CurrentData = Common.ObjectAttributesValues(ElemRef, AttributesList + ", Companies");
		CurrentRefCompaniesTable = CurrentData.Companies.Unload();
	EndIf;
	
	If NewRef 
		Or Not CheckEqualsElementAttributes(CurrentData, HistoryParameters, AttributesList) Then

		RegSet = InformationRegisters.MasterChartOfAccountsHistory.CreateRecordSet();
		
		RegSet.Filter.Period.Set(CurrentSessionDate());
		RegSet.Filter.ChartOfAccounts.Set(ElemRef);
		RegSet.Filter.Company.Set(Catalogs.Companies.EmptyRef());
		
		RegEntry = RegSet.Add();
		RegEntry.ChartOfAccounts	= ElemRef;
		RegEntry.Period				= CurrentSessionDate();
		RegEntry.StartDate			= HistoryParameters.StartDate;
		RegEntry.EndDate			= HistoryParameters.EndDate;
		RegEntry.User				= SessionParameters.CurrentUser;
		RegEntry.UseQuantity				= HistoryParameters.UseQuantity;
		RegEntry.UseAnalyticalDimensions	= HistoryParameters.UseAnalyticalDimensions;
		RegEntry.AnalyticalDimensionsSet	= HistoryParameters.AnalyticalDimensionsSet;
		
		RegSet.Write(True);
		
	EndIf;
		
	For Each CompanyRow In HistoryParameters.CompaniesTable Do
		
		FilterStr = New Structure("Company", CompanyRow.Company);
		
		If Not NewRef Then
			RefCompanyRows = CurrentRefCompaniesTable.FindRows(FilterStr);
		EndIf;
		
		If NewRef 
			Or (RefCompanyRows.Count() = 0 
				Or CompanyRow.StartDate <> RefCompanyRows[0].StartDate 
				Or CompanyRow.EndDate <> RefCompanyRows[0].EndDate) Then
			
			RegSet = InformationRegisters.MasterChartOfAccountsHistory.CreateRecordSet();
			
			RegSet.Filter.Period.Set(CurrentSessionDate());
			RegSet.Filter.ChartOfAccounts.Set(ElemRef);
			RegSet.Filter.Company.Set(CompanyRow.Company);
			
			RegEntry = RegSet.Add();
			RegEntry.ChartOfAccounts			= ElemRef;
			RegEntry.Company					= CompanyRow.Company;
			RegEntry.Period						= CurrentSessionDate();
			RegEntry.StartDate					= CompanyRow.StartDate;
			RegEntry.EndDate					= CompanyRow.EndDate;
			RegEntry.User 						= SessionParameters.CurrentUser;
			RegEntry.UseQuantity				= HistoryParameters.UseQuantity;
			RegEntry.UseAnalyticalDimensions	= HistoryParameters.UseAnalyticalDimensions;
			RegEntry.AnalyticalDimensionsSet	= HistoryParameters.AnalyticalDimensionsSet;
			
			RegSet.Write(True);
			
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function CheckEqualsElementAttributes(ElemRef, HistoryParameters, AttributeList)
	
	AttributeArray = StrSplit(AttributeList, ",");

	For Each Item In AttributeArray Do
		
		If ElemRef[TrimAll(Item)] <> HistoryParameters[TrimAll(Item)] Then
			
			Return False;
			
		EndIf;
		
	EndDo;
	
	Return True;

EndFunction

#EndRegion

#EndIf
