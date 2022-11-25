#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure SetPredefinedDuplicateRules() Export
	
	// Contact persons and Contact persons
	Reference = Catalogs.DuplicateRules.ContactPersonsAndContactPersons;
	
	If Not ValueIsFilled(Reference.TypeOfNewObject) Then
		
		Object = Reference.GetObject();
		Object.TypeOfNewObject = Enums.DuplicateObjectsTypes.ContactPersons;
		Object.TypeOfExistingObject = Enums.DuplicateObjectsTypes.ContactPersons;
		
		Object.MatchingCriterias.Clear();
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.ContactInformation;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.ContactInformation;
		NewLine.Use = True;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.Use = False;
		
		Object.Write();
	EndIf;
	
	// Counterparties and Counterparties
	Reference = Catalogs.DuplicateRules.CounterpartiesAndCounterparties;
	
	If Not ValueIsFilled(Reference.TypeOfNewObject) Then
		
		Object = Reference.GetObject();
		Object.TypeOfNewObject = Enums.DuplicateObjectsTypes.Counterparties;
		Object.TypeOfExistingObject = Enums.DuplicateObjectsTypes.Counterparties;
		
		Object.MatchingCriterias.Clear();
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.ContactInformation;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.ContactInformation;
		NewLine.Use = False;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.Use = False;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewLine.Use = False;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.VATNumber;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.VATNumber;
		NewLine.Use = True;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.RegistrationNumber;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.RegistrationNumber;
		NewLine.Use = True;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewLine.Use = False;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.Use = False;
		
		Object.Write();
		
	EndIf;
	
	// Leads and Leads
	Reference = Catalogs.DuplicateRules.LeadsAndLeads;
	
	If Not ValueIsFilled(Reference.TypeOfNewObject) Then
		
		Object = Reference.GetObject();
		Object.TypeOfNewObject = Enums.DuplicateObjectsTypes.Leads;
		Object.TypeOfExistingObject = Enums.DuplicateObjectsTypes.Leads;
		
		Object.MatchingCriterias.Clear();
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.ContactInformation;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.ContactInformation;
		NewLine.Use = True;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.Use = False;
		
		Object.Write();
	EndIf;
	
	// Products and Products
	Reference = Catalogs.DuplicateRules.ProductsAndProducts;
	
	If Not ValueIsFilled(Reference.TypeOfNewObject) Then
		
		Object = Reference.GetObject();
		Object.TypeOfNewObject = Enums.DuplicateObjectsTypes.Products;
		Object.TypeOfExistingObject = Enums.DuplicateObjectsTypes.Products;
		
		Object.MatchingCriterias.Clear();
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.SKU;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.SKU;
		NewLine.Use = True;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.Description;
		NewLine.Use = True;
		
		NewLine = Object.MatchingCriterias.Add();
		NewLine.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewLine.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewLine.Use = True;
		
		Object.Write();
	EndIf;
	
EndProcedure

Procedure ChangeProductsAndProductsDuplicateRules() Export
	
	Reference = Catalogs.DuplicateRules.ProductsAndProducts;
	
	Object = Reference.GetObject();
	
	For Each Row In Object.MatchingCriterias Do
		If Row.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.Description
			And Row.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.Description
			And Not Row.Use Then
			Row.Use = True;
			Object.Write();
			Return;
		EndIf;
	EndDo;
	
EndProcedure

Procedure ChangeCounterpartiesAndCounterpartiesDuplicateRules() Export
	
	Reference = Catalogs.DuplicateRules.CounterpartiesAndCounterparties;
	
	Object = Reference.GetObject();
	
	For Each Row In Object.MatchingCriterias Do
		If (Row.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.Description
			Or Row.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.Description
			Or Row.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.DescriptionFull
			Or Row.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.DescriptionFull)
			And Not Row.Use Then
			Row.Use = True;
		EndIf;
	EndDo;
	
	BeginTransaction();
	Try
		Object.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		
		Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot rewrite ""%1""'; ru = 'Не удалось перезаписать ""%1""';pl = 'Nie można przepisać %1""';es_ES = 'Ha ocurrido un error al sobrescribir ""%1""';es_CO = 'Ha ocurrido un error al sobrescribir ""%1""';tr = '""%1"" yeniden yazılamıyor';it = 'Impossibile riscrivere ""%1""';de = '%1"" kann nicht neu gespeichert werden'", CommonClientServer.DefaultLanguageCode()),
			Reference);
			
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Error, Comment);
		
	EndTry;
	
EndProcedure

Procedure AddDescriptionFullDuplicateRule() Export
	
	Reference = Catalogs.DuplicateRules.ProductsAndProducts;
	DescriptionFull = Enums.DuplicateObjectsCriterias.DescriptionFull;
	
	Object = Reference.GetObject();
	SearchStrucutre = New Structure("CriteriaOfNewObject, CriteriaOfExistingObject", DescriptionFull, DescriptionFull);
	FoundRows = Object.MatchingCriterias.FindRows(SearchStrucutre);
	
	If FoundRows.Count() = 0 Then
		NewRow = Object.MatchingCriterias.Add();
		NewRow.CriteriaOfNewObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewRow.CriteriaOfExistingObject = Enums.DuplicateObjectsCriterias.DescriptionFull;
		NewRow.Use = True;
		
	Try
		Object.Write();
	Except
		
		Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot rewrite ""%1""'; ru = 'Не удалось перезаписать ""%1""';pl = 'Nie można przepisać %1""';es_ES = 'Ha ocurrido un error al sobrescribir ""%1""';es_CO = 'Ha ocurrido un error al sobrescribir ""%1""';tr = '""%1"" yeniden yazılamıyor';it = 'Impossibile riscrivere ""%1""';de = '%1"" kann nicht neu gespeichert werden'", CommonClientServer.DefaultLanguageCode()),
			Reference);
			
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Error, Comment);
		
	EndTry;
		
	EndIf;

EndProcedure

#EndRegion

#EndIf