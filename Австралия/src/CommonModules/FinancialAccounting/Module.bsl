#Region Private

Procedure SaveMapSettings(TranslationTemplate = Undefined, AccountsMapping = Undefined, NewValues = Undefined) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.MappingRules.CreateRecordSet();
	
	If ValueIsFilled(TranslationTemplate) Then
		RecordSet.Filter.TranslationTemplate.Set(TranslationTemplate);
	EndIf;
	
	If ValueIsFilled(AccountsMapping) Then
		RecordSet.Filter.AccountsMapping.Set(AccountsMapping);
	EndIf;
	
	RecordSet.Read();
	RecordSet.Clear();
	
	If NewValues <> Undefined Then
		
		NewRow = RecordSet.Add();
		FillPropertyValues(NewRow, NewValues);
		
		NewRow.TranslationTemplate = TranslationTemplate;
		NewRow.AccountsMapping = AccountsMapping;
		
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

Procedure FillChartOfAccountsList(List) Export
	
	ChartsFullNames = New Array;
	
	For Each MetaChart In Metadata.ChartsOfAccounts Do
		ChartsFullNames.Add(MetaChart.FullName());
	EndDo;
	
	ChartIDs = Common.MetadataObjectIDs(ChartsFullNames);
	
	For Each MetaChart In Metadata.ChartsOfAccounts Do
		MetadataObjectID = ChartIDs[MetaChart.FullName()];
		List.Add(MetadataObjectID, MetaChart.Presentation());
	EndDo;
	
EndProcedure

Function GetAccountinRegisterByChartOfAccounts(ChartOfAccountsID) Export
	
	MetadataObjectID = Undefined;
	
	If ValueIsFilled(ChartOfAccountsID) Then
		
		MetadataChartOfAccounts = Common.MetadataObjectByID(ChartOfAccountsID);
		
		For Each MetadataAccountingRegister In Metadata.AccountingRegisters Do
			
			If MetadataAccountingRegister.ChartOfAccounts = MetadataChartOfAccounts Then
				
				MetadataObjectID = Common.MetadataObjectID(MetadataAccountingRegister.FullName());
				
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return MetadataObjectID;
	
EndFunction

Procedure FillExtraDimensions(Ref, AccountingTable) Export
	
	// This code will be overridden in the extension.
	
EndProcedure

#EndRegion