
#Region Public

Function GetIncomeAndExpenseItemsDescription(FillingData) Export

	Items = "";
	ItemsFilled = True;
	
	UnfilledAccountPresentation = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	DisabledAccountPresentation = GetDisabledIncomeAndExpenseItemsPresentation();

	FirstItem = True;
	For Each Item In FillingData Do
		
		If TypeOf(Item.Value) <> Type("CatalogRef.IncomeAndExpenseItems") Then
			Continue;	
		EndIf;
		
		If ValueIsFilled(Item.Value) Then
			Items = Items + ?(FirstItem, "", ", ") + Item.Value;
		Else
			Items = Items + UnfilledAccountPresentation;
			ItemsFilled	= False;
		EndIf;
		
		If FirstItem Then
			FirstItem = False;
			UnfilledAccountPresentation = ", " + UnfilledAccountPresentation;
		EndIf;
		
	EndDo;
	
	FillingData.Insert("IncomeAndExpenseItems",			?(IsBlankString(Items), DisabledAccountPresentation, Items));
	FillingData.Insert("IncomeAndExpenseItemsFilled",	ItemsFilled);
	
	Return FillingData;
	
EndFunction

Function GetIncomeAndExpenseStructureData(Object, TabName = "Inventory", ProductName= "Products") Export
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, TabName,, ProductName);
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, TabName);
	
	If StructureData.ObjectParameters.Property(TabName) Then
		StructureData.ObjectParameters.Delete(TabName);
	EndIf;
	
	Return StructureData;
	
EndFunction

Function GetDisabledIncomeAndExpenseItemsPresentation() Export
	Return NStr("en = '<Inapplicable>'; ru = '<Неприменимо>';pl = '<Nie dotyczy>';es_ES = '<Inaplicable>';es_CO = '<Inaplicable>';tr = '<Uygulanamaz>';it = '<Non applicabile>';de = '<Nicht verwendbar>'");
EndFunction

#EndRegion
