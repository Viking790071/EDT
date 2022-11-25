#Region Public

Function HasReferences(ReportItem, RefsCount = 0) Export
	
	HasRefs = False;
	Query = New Query;
	TempTablesManager = FinancialReportingServer.PicturesIndexesTable();
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = FinancialReportingServer.ReportItemReferencesQueryText();
	Query.SetParameter("ReportItem", ReportItem);
	Query.SetParameter("Owner", ReportItem.Owner);
	
	Selection = Query.Execute().Select();
	RefsCount = Selection.Count();
	If Selection.Next() Then
		HasRefs = True;
	EndIf;
	Return HasRefs;
	
EndFunction

Function NonstandardPicture(ItemType, AuxiliaryDataName = Undefined) Export
	
	Return FinancialReportingCached.NonstandardPicture(ItemType, AuxiliaryDataName);
	
EndFunction

Function PutItemToTempStorage(PutObject, StorageAddress = Undefined, ClearReferences = False) Export
	
	ItemStructure = ReportItemData(PutObject);
	
	If ClearReferences Then
		
		ItemStructure.Ref = Undefined;
		ItemStructure.Owner = Undefined;
		
		Operands = New Array;
		For Each OperandRow In ItemStructure.FormulaOperands Do
			If TypeOf(OperandRow.Operand) = Type("CatalogRef.FinancialReportsItems") Then
				Operands.Add(OperandRow.Operand);
			EndIf;
		EndDo;
		
		If Operands.Count() = 0 Then
			AttributesValues = Undefined;
		Else 
			ItemsProperties  = FinancialReportingClientServer.ReportItemStructure();
			ReceivedValues = "";
			For Each KeyValue In ItemsProperties Do
				ReceivedValues = ReceivedValues + ?(ReceivedValues = "", "", ", ") + KeyValue.Key;
			EndDo;
			AttributesValues = Common.ObjectsAttributesValues(Operands, ReceivedValues);
		EndIf;
		
		For Each OperandRow In ItemStructure.FormulaOperands Do
			Data = ReportItemData(OperandRow.Operand, AttributesValues);
			Data.Ref = Undefined;
			Data.Owner = Undefined;
			OperandRow.ItemStructureAddress = PutToTempStorage(Data, StorageAddress);
			OperandRow.Operand = Undefined;
		EndDo;
		
	EndIf;
	
	Return PutToTempStorage(ItemStructure, StorageAddress);
	
EndFunction

Function ReportItemData(ReportItem, AttributesValues = Undefined) Export
	
	ItemStructure = FinancialReportingClientServer.ReportItemStructure();
	If TypeOf(ReportItem) = Type("CatalogObject.FinancialReportsItems") Then
		FillPropertyValues(ItemStructure, ReportItem);
		CopyItemTables(ReportItem, ItemStructure);
	ElsIf TypeOf(ReportItem) = Type("CatalogRef.FinancialReportsItems") Then
		If ValueIsFilled(ReportItem) Then
			CacheFoundValue = Undefined;
			If AttributesValues <> Undefined Then
				CacheFoundValue = AttributesValues.Get(ReportItem);
			EndIf;
		EndIf;
		If CacheFoundValue = Undefined Then
			ItemStructure = Common.ObjectAttributesValues(ReportItem, ItemStructure);
		Else
			ItemStructure = CacheFoundValue;
		EndIf;
		If ValueIsFilled(ItemStructure.Ref) Then
			CopyItemTables(ItemStructure, ItemStructure);
		EndIf;
	ElsIf TypeOf(ReportItem) = Type("Structure") Then
		FillPropertyValues(ItemStructure, ReportItem);
		For Each KeyValue In ReportItem Do
			If StrFind(KeyValue.Key, "AdditionalAttribute_") Then
				AdditionalAttributeName = StrReplace(KeyValue.Key, "AdditionalAttribute_", "");
				SetAdditionalAttributeValue(ItemStructure, AdditionalAttributeName, KeyValue.Value)
			EndIf;
		EndDo;
	Else
		Raise NStr("en = 'Object type undefined'; ru = 'Тип объекта не определен';pl = 'Nie określono typu obiektu';es_ES = 'Tipo de objeto indefinido';es_CO = 'Tipo de objeto indefinido';tr = 'Nesne türü tanımlanmamış';it = 'Tipo di oggetto non definito';de = 'Objekttyp undefiniert'");
	EndIf;
	
	ItemStructure.Insert("IsLinked", ValueIsFilled(ItemStructure.LinkedItem));
	
	If TypeOf(ItemStructure.FormulaOperands) <> Type("ValueTable") Then
		ItemStructure.FormulaOperands = New ValueTable;
		ItemStructure.FormulaOperands.Columns.Add("ID");
		ItemStructure.FormulaOperands.Columns.Add("Operand");
	EndIf;
	If TypeOf(ItemStructure.ItemTypeAttributes) <> Type("ValueTable") Then
		ItemStructure.ItemTypeAttributes = New ValueTable;
		ItemStructure.ItemTypeAttributes.Columns.Add("Attribute");
		ItemStructure.ItemTypeAttributes.Columns.Add("Value");
	EndIf;
	If TypeOf(ItemStructure.TableItems) <> Type("ValueTable") Then
		ItemStructure.TableItems = New ValueTable;
		ItemStructure.TableItems.Columns.Add("Row");
		ItemStructure.TableItems.Columns.Add("Column");
		ItemStructure.TableItems.Columns.Add("Item");
	EndIf;
	If TypeOf(ItemStructure.AdditionalFields) <> Type("ValueTable") Then
		ItemStructure.AdditionalFields = New ValueTable;
		ItemStructure.AdditionalFields.Columns.Add("Attribute");
		ItemStructure.AdditionalFields.Columns.Add("Description");
		ItemStructure.AdditionalFields.Columns.Add("OutputTitle");
	EndIf;
	If TypeOf(ItemStructure.AppearanceItems) <> Type("ValueTable") Then
		ItemStructure.AppearanceItems = New ValueTable;
		ItemStructure.AppearanceItems.Columns.Add("Appearance");
		ItemStructure.AppearanceItems.Columns.Add("Condition");
		ItemStructure.AppearanceItems.Columns.Add("AppearanceAppliedAreaType");
		ItemStructure.AppearanceItems.Columns.Add("AppearanceItemKey");
	EndIf;
	If TypeOf(ItemStructure.AppearanceAppliedRows) <> Type("ValueTable") Then
		ItemStructure.AppearanceAppliedRows = New ValueTable;
		ItemStructure.AppearanceAppliedRows.Columns.Add("ReportItem");
		ItemStructure.AppearanceAppliedRows.Columns.Add("AppearanceItemKey");
	EndIf;
	If TypeOf(ItemStructure.AppearanceAppliedColumns) <> Type("ValueTable") Then
		ItemStructure.AppearanceAppliedColumns = New ValueTable;
		ItemStructure.AppearanceAppliedColumns.Columns.Add("ReportItem");
		ItemStructure.AppearanceAppliedColumns.Columns.Add("AppearanceItemKey");
	EndIf;
	If TypeOf(ItemStructure.AppearanceItemsFilterFieldsDetails) <> Type("ValueTable") Then
		ItemStructure.AppearanceItemsFilterFieldsDetails = New ValueTable;
		ItemStructure.AppearanceItemsFilterFieldsDetails.Columns.Add("AppearanceItemKey");
		ItemStructure.AppearanceItemsFilterFieldsDetails.Columns.Add("ReportItem");
		ItemStructure.AppearanceItemsFilterFieldsDetails.Columns.Add("FilterFieldName");
		ItemStructure.AppearanceItemsFilterFieldsDetails.Columns.Add("ResourceName");
	EndIf;
	If TypeOf(ItemStructure.ValuesSources) <> Type("ValueTable") Then
		ItemStructure.ValuesSources = New ValueTable;
		ItemStructure.ValuesSources.Columns.Add("Source");
		ItemStructure.ValuesSources.Columns.Add("DocumentAddedValues");
	EndIf;
	
	If ItemStructure.FormulaOperands.Columns.Find("ItemStructureAddress") = Undefined Then
		ItemStructure.FormulaOperands.Columns.Add("ItemStructureAddress");
	EndIf;
	
	Return ItemStructure;
	
EndFunction

Procedure SetAdditionalAttributeValue(Source, Val Attribute, Value) Export
	
	If TypeOf(Source) = Type("String") Then
		Object = GetFromTempStorage(Source);
	Else
		Object = Source;
	EndIf;
	
	If Object.ItemTypeAttributes = Undefined Then
		AttributesTable = New ValueTable;
		AttributesTable.Columns.Add("Attribute");
		AttributesTable.Columns.Add("Value");
		AttributesTable.Indexes.Add("Attribute");
		Object.ItemTypeAttributes = AttributesTable;
	EndIf;
	
	If TypeOf(Attribute) = Type("String") Then
		Attribute = ChartsOfCharacteristicTypes.FinancialReportsItemsAttributes[Attribute];
	EndIf;
	
	FoundRow = Object.ItemTypeAttributes.Find(Attribute);
	If FoundRow = Undefined Then
		FoundRow = Object.ItemTypeAttributes.Add();
		FoundRow.Attribute = Attribute;
	EndIf;
	
	FoundRow.Value = Value;
	
	If FoundRow.Value = Undefined Then
		Object.ItemTypeAttributes.Delete(FoundRow);
	EndIf;
	
	If TypeOf(Source) = Type("String") Then
		PutToTempStorage(Object, Source);
	EndIf;
	
EndProcedure

Function AdditionalAttributeValue(ItemRef, Attribute) Export
	
	Return AdditionalAttributesValues(ItemRef, Attribute)[Attribute];
	
EndFunction

Function AdditionalAttributesValues(ItemRef, Attributes) Export
	
	If TypeOf(ItemRef) = Type("String") Then
		Object = GetFromTempStorage(ItemRef);
	ElsIf TypeOf(ItemRef) = Type("CatalogRef.FinancialReportsItems") Then
		Object = Common.ObjectAttributesValues(ItemRef, "ItemTypeAttributes");
		Object.ItemTypeAttributes = Object.ItemTypeAttributes.Unload();
	Else
		Object = ItemRef;
	EndIf;
	
	AttributesStructure = New Structure(Attributes);
	Cache = Object.ItemTypeAttributes;
	
	Result = New Structure;
	
	For Each KeyValue In AttributesStructure Do
		Result.Insert(KeyValue.Key, 
			FinancialReportingServer.AdditionalAttributeValue(
				Undefined, 
				ChartsOfCharacteristicTypes.FinancialReportsItemsAttributes[KeyValue.Key],
				Cache));
	EndDo;
		
	Return Result;
	
EndFunction

Function ObjectAttributeValue(Ref, AttributeName) Export
	
	If TypeOf(Ref) = Type("String") Then
		ItemStructure = GetFromTempStorage(Ref);
		Return ItemStructure[AttributeName];
	Else
		Return Common.ObjectAttributeValue(Ref, AttributeName);
	EndIf;
	
EndFunction

Function FormUsageParameters(ItemType, Item, AdditionalMode = Undefined) Export
	
	AdditionalModes = Enums.ReportItemsAdditionalModes;
	DimensionsTypes = Enums.FinancialReportDimensionTypes;
	
	AdditionalAttribuesStructure = New Structure;
	AdditionalAttributes = ChartsOfCharacteristicTypes.FinancialReportsItemsAttributes;
	ItemFormName = Undefined;
	If AdditionalMode = AdditionalModes["LinkedItem"] Then
		
		ItemFormName = "Form.LinkedItem";
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.RowCode.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Note.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.MarkItem.PredefinedDataName);
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.ReportTitle
		Or ItemType = Enums.FinancialReportItemsTypes.NonEditableText
		Or ItemType = Enums.FinancialReportItemsTypes.EditableText Then
		
		ItemFormName = "Form.TextBlock";
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Text.PredefinedDataName);
		If IsTempStorageURL(Item) Then
			ItemParameters = GetFromTempStorage(Item);
			ItemOwner = ?(ItemParameters.Property("Owner"), ItemParameters.Owner, Undefined);
		Else
			ItemOwner = Item.Owner;
		EndIf;
		
	ElsIf (ItemType = Enums.FinancialReportItemsTypes.Group
		Or ItemType = Enums.FinancialReportItemsTypes.GroupTotal) Then
		
		If AdditionalMode = AdditionalModes["ShowRowCodeAndNote"] Then
			ItemFormName = "Form.Group";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.OutputItemTitle.PredefinedDataName);
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.RowCode.PredefinedDataName);
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.Note.PredefinedDataName);
		Else
			ItemFormName = "Form.Group";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.OutputItemTitle.PredefinedDataName);
		EndIf;
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.TableComplex
		Or ItemType = Enums.FinancialReportItemsTypes.TableIndicatorsInColumns
		Or ItemType = Enums.FinancialReportItemsTypes.TableIndicatorsInRows Then
		
		ItemFormName = "Form.Table";
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.OutputItemTitle.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.OutputGroupingTitle.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.GroupingTitle.PredefinedDataName);
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.TableItem Then
		
		ItemFormName = "Form.TableItem";
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.RowCode.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Note.PredefinedDataName);
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.AccountingDataIndicator Then
		
		ItemFormName = "Form.AccountingDataIndicator";
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Account.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.TotalsType.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.OpeningBalance.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.RowCode.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Note.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.MarkItem.PredefinedDataName);
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.UserDefinedFixedIndicator Then
		
		ItemFormName = "Form.UserDefinedFixedIndicator";
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.UserDefinedFixedIndicator.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.RowCode.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Note.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.MarkItem.PredefinedDataName);
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator Then
		
		ItemFormName = "Form.ReportUserDefinedCalculatedIndicator";
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Formula.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.RowCode.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.Note.PredefinedDataName);
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.MarkItem.PredefinedDataName);
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.ConfigureCells Then
		
		ItemFormName = "Form.ReportTypeCellsConfiguration";
		
	ElsIf ItemType = Enums.FinancialReportItemsTypes.Dimension Then
		
		AdditionalAttribuesStructure.Insert(AdditionalAttributes.DimensionType.PredefinedDataName);
		DimensionType = AdditionalAttributeValue(Item, "DimensionType");
		
		If DimensionType = DimensionsTypes["Period"] Then
			
			ItemFormName = "Form.ReportTypePeriod";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.Periodicity.PredefinedDataName);
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.Sort.PredefinedDataName);
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.PeriodPresentation.PredefinedDataName);
			
		ElsIf DimensionType = DimensionsTypes["RegisterDimension"]
			Or DimensionType = DimensionsTypes["AccountingRegisterDimension"] Then
			
			ItemFormName = "Form.RegisterDimension";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.DimensionName.PredefinedDataName);
			If Not DimensionType = DimensionsTypes["AccountingRegisterDimension"] Then
				AdditionalAttribuesStructure.Insert(AdditionalAttributes.SelectedValuesSources.PredefinedDataName);
			EndIf;
			
		ElsIf DimensionType = DimensionsTypes["AnalyticalDimension"] Then
			
			ItemFormName = "Form.RegisterDimension";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.AnalyticalDimensionType.PredefinedDataName);
			
		ElsIf DimensionType = DimensionsTypes["Company"] Then
			
			ItemFormName = "Form.Company";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.Company.PredefinedDataName);
			
		ElsIf DimensionType = DimensionsTypes["BusinessUnit"] Then
			
			ItemFormName = "Form.BusinessUnit";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.BusinessUnit.PredefinedDataName);
			
		ElsIf DimensionType = DimensionsTypes["Currency"] Then
			
			ItemFormName = "Form.Currency";
			AdditionalAttribuesStructure.Insert(AdditionalAttributes.Currency.PredefinedDataName);
			
		EndIf;
		
	EndIf;
	
	If ItemFormName = Undefined Then
		Raise NStr("en = 'Unknown report item type'; ru = 'Тип элемента отчета не известен';pl = 'Nieznany typ pozycji raportu';es_ES = 'Tipo de elemento de informe desconocido';es_CO = 'Tipo de elemento de informe desconocido';tr = 'Bilinmeyen rapor ögesi türü';it = 'Tipo di elemento di report sconosciuto';de = 'Unbekannter Berichtselementtyp'");
	EndIf;
	
	Return New Structure(
				"FormName, Attributes",
				"Catalog.FinancialReportsItems." + ItemFormName,
				AdditionalAttribuesStructure);
	
EndFunction

Function CopyItemByAddress(ItemAddress, StorageID, ItemType = Undefined) Export
	
	ItemCopy = FinancialReportingClientServer.ReportItemStructure();
	ItemData = GetFromTempStorage(ItemAddress);
	FillPropertyValues(ItemCopy, ItemData);
	ItemCopy.Ref = Undefined;
	
	ItemCopy.ItemTypeAttributes = ItemData.ItemTypeAttributes.Copy();
	ItemCopy.FormulaOperands = ItemData.FormulaOperands.Copy();
	ItemCopy.AdditionalFields = ItemData.AdditionalFields.Copy();
	
	For Each OperandRow In ItemCopy.FormulaOperands Do
		If Not ValueIsFilled(OperandRow.ItemStructureAddress) Then
			OperandRow.ItemStructureAddress = PutItemToTempStorage(OperandRow.Operand, StorageID);
		EndIf;
		OperandAddress = CopyItemByAddress(OperandRow.ItemStructureAddress, StorageID);
		OperandRow.ItemStructureAddress = OperandAddress;
		OperandRow.Operand = Undefined;
	EndDo;
	
	ItemType = ItemCopy.ItemType;
	
	Return PutToTempStorage(ItemCopy, StorageID);
	
EndFunction

Function BuildOperatorsTree(ConditionForQuery = True) Export
	
	Tree = FinancialReportingServer.GetOperandsEmptyTree();
	
	OperatorsGroup = FinancialReportingServer.AddOperatorsGroup(Tree, NStr("en = 'Operators'; ru = 'Операторы';pl = 'Operatorzy';es_ES = 'Operadores';es_CO = 'Operadores';tr = 'Operatörler';it = 'Operatori';de = 'Operatoren'"));
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "+", " + ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "-", " - ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "*", " * ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "/", " / ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "( )", " ( ) ");
	
	OperatorsGroup = FinancialReportingServer.AddOperatorsGroup(Tree, NStr("en = 'Logical operators and constants'; ru = 'Логические операторы и константы';pl = 'Operatory logiczne i konstanty';es_ES = 'Operadores lógicos y constantes';es_CO = 'Operadores lógicos y constantes';tr = 'Mantıksal işleçler ve sabitler';it = 'Operatori logici e costanti';de = 'Logische Operatoren und Konstanten'"));
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "<", " < ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, ">", " > ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "<=", " <= ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, ">=", " >= ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "=", " = ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, "<>", " <> ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, NStr("en = 'AND'; ru = 'И';pl = 'AND';es_ES = 'Y';es_CO = 'Y';tr = 'VE';it = 'E';de = 'UND'"), " " + NStr("en = 'AND'; ru = 'И';pl = 'AND';es_ES = 'Y';es_CO = 'Y';tr = 'VE';it = 'E';de = 'UND'") + " ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, NStr("en = 'OR'; ru = 'ИЛИ';pl = 'OR';es_ES = 'O';es_CO = 'O';tr = 'VEYA';it = 'O';de = 'ODER'"), " " + NStr("en = 'OR'; ru = 'ИЛИ';pl = 'OR';es_ES = 'O';es_CO = 'O';tr = 'VEYA';it = 'O';de = 'ODER'") + " ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, NStr("en = 'NOT'; ru = 'НЕ';pl = 'NOT';es_ES = 'NO';es_CO = 'NO';tr = 'DEĞİL';it = 'NOT';de = 'NICHT'"), " " + NStr("en = 'NOT'; ru = 'НЕ';pl = 'NOT';es_ES = 'NO';es_CO = 'NO';tr = 'DEĞİL';it = 'NOT';de = 'NICHT'") + " ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, NStr("en = 'TRUE'; ru = 'ИСТИНА';pl = 'TRUE';es_ES = 'VERDADERO';es_CO = 'VERDADERO';tr = 'TRUE';it = 'TRUE';de = 'WAHR'"), " " + NStr("en = 'TRUE'; ru = 'ИСТИНА';pl = 'TRUE';es_ES = 'VERDADERO';es_CO = 'VERDADERO';tr = 'TRUE';it = 'TRUE';de = 'WAHR'") + " ");
	FinancialReportingServer.AddOperator(Tree, OperatorsGroup, NStr("en = 'FALSE'; ru = 'ЛОЖЬ';pl = 'FALSE';es_ES = 'FALSO';es_CO = 'FALSO';tr = 'FALSE';it = 'FALSO';de = 'FALSE'"), " " + NStr("en = 'FALSE'; ru = 'ЛОЖЬ';pl = 'FALSE';es_ES = 'FALSO';es_CO = 'FALSO';tr = 'FALSE';it = 'FALSO';de = 'FALSE'") + " ");
	
	OperatorsGroup = FinancialReportingServer.AddOperatorsGroup(Tree, NStr("en = 'Functions'; ru = 'Функции';pl = 'Funkcje';es_ES = 'Funciones';es_CO = 'Funciones';tr = 'İşlevler';it = 'Funzioni';de = 'Rollen'"));
	If ConditionForQuery Then
		FinancialReportingServer.AddOperator(Tree, OperatorsGroup, NStr("en = 'Condition'; ru = 'Условие';pl = 'Warunek';es_ES = 'Condición';es_CO = 'Condición';tr = 'Koşul';it = 'Condizione';de = 'Bedingung'"), NStr("en = 'CASE WHEN <Condition> THEN <ResultTrue> ELSE <ResultFalse> END'; ru = 'ВЫБОР КОГДА <Condition> ТОГДА <ResultTrue> ИНАЧЕ <ResultFalse> КОНЕЦ';pl = 'CASE WHEN <Condition> THEN <ResultTrue> ELSE <ResultFalse> END';es_ES = 'EL CASO CUANDO <Condition> ENTONCES <ResultTrue> MÁS <ResultFalse> FINAL';es_CO = 'EL CASO CUANDO <Condition> ENTONCES <ResultTrue> MÁS <ResultFalse> FINAL';tr = 'CASE WHEN <Condition> THEN <ResultTrue> ELSE <ResultFalse> END';it = 'CASE WHEN <Condition> THEN <ResultTrue> ELSE <ResultFalse> END';de = 'FALL WENN <Condition> DANN <ResultTrue> SONST <ResultFalse> ENDE'"), 3);
	Else
		FinancialReportingServer.AddOperator(Tree, OperatorsGroup, NStr("en = 'Condition'; ru = 'Условие';pl = 'Warunek';es_ES = 'Condición';es_CO = 'Condición';tr = 'Koşul';it = 'Condizione';de = 'Bedingung'"), NStr("en = '?(<Condition>, <ResultTrue>, <ResultFalse>)'; ru = '?(<Condition>, <ResultTrue>, <ResultFalse>)';pl = '?(<Condition>, <ResultTrue>, <ResultFalse>)';es_ES = '?(<Condition>, <ResultTrue>, <ResultFalse>)';es_CO = '?(<Condition>, <ResultTrue>, <ResultFalse>)';tr = '?(<Condition>, <ResultTrue>, <ResultFalse>)';it = '?(<Condition>, <ResultTrue>, <ResultFalse>)';de = '?(<Condition>, <ResultTrue>, <ResultFalse>)'"), 3);
	EndIf;
	
	Return Tree;
	
EndFunction

Procedure CheckFormula(Formula, Operands, Cancel, Field = "", DataPath = "") Export
	
	OperandsValues = IndicatorItemEmptyTable();
	
	If IsBlankString(Formula) Then
		NotificationText = NStr("en = 'Formula text is not specified.'; ru = 'Текст формулы не указан.';pl = 'Nie okeślono tekstu formuły.';es_ES = 'El texto de la fórmula no está especificado.';es_CO = 'El texto de la fórmula no está especificado.';tr = 'Formül metni belirtilmemiş.';it = 'Il testo della formula non è specificato.';de = 'Der Formeltext ist nicht angegeben.'");
		CommonClientServer.MessageToUser(NotificationText, , Field, DataPath,);
	EndIf;
	
	SelectionPeriod = FinancialReportingServer.ReportPeriod(Date('00010101'), Date('00010101'));
	ReportIntervals = Catalogs.FinancialReportsItems.ReportIntervals(SelectionPeriod);
	
	DCSchema = Catalogs.FinancialReportsItems.GetTemplate("UserDefinedCalculatedIndicator");
	NumberType = Common.TypeDescriptionNumber(15, 2);
	LFTab = Chars.LF + Chars.Tab;
	UnusedOperands = "";
	AccountingDataIndicator = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	For Each Operand In Operands Do
		NewSetField = FinancialReportingServer.NewSetField(DCSchema.DataSets.OperandsValues, Operand.ID, , , NumberType);
		OperandsValues.Columns.Add(Operand.ID, Common.TypeDescriptionNumber(15, 2));
		ID = "[" + Operand.ID + "]";
		If StrFind(Formula, ID) = 0 Then
			UnusedOperands = UnusedOperands + ID + " " + Operand.DescriptionForPrinting + LFTab;
		EndIf;
		If Operand.ItemType = AccountingDataIndicator And Not ValueIsFilled(Operand.Account) Then
			Pattern = NStr("en = 'Account is not specified in [%1] %2 operand''s settings.'; ru = 'Счет не указан в настройках операнда [%1] %2.';pl = 'Nie określono konta w ustawieniach operandu [%1] %2.';es_ES = 'La cuenta no está especificada en [%1] %2 las configuraciones del operando.';es_CO = 'La cuenta no está especificada en [%1] %2 las configuraciones del operando.';tr = '[%1] %2 işlenenin ayarlarında hesap belirtilmemiş.';it = 'Il conto non è specificato nelle impostazioni dell''operatore [%1] %2';de = 'Das Konto ist in den Einstellungen des Operanden [%1] %2 nicht angegeben.'");
			Text = StringFunctionsClientServer.SubstituteParametersToString(Pattern, Operand.ID, Operand.DescriptionForPrinting);
			CommonClientServer.MessageToUser(Text, , Field, DataPath,);
		EndIf;
	EndDo;
	If Not IsBlankString(UnusedOperands) Then
		NotificationText = NStr("en = 'Unused operands found:'; ru = 'Найдены неиспользуемые операнды:';pl = 'Znaleziono nieużywane operandy:';es_ES = 'Se han encontrado operandos no utilizados:';es_CO = 'Se han encontrado operandos no utilizados:';tr = 'Kullanılmayan işlenenler bulundu:';it = 'Operatori non usati trovati:';de = 'Nicht verwendete Operanden gefunden:'") + LFTab + UnusedOperands;
		CommonClientServer.MessageToUser(NotificationText, , Field, DataPath,);
	EndIf;
	ValueField = DCSchema.CalculatedFields[0];
	ValueField.Expression = ?(ValueIsFilled(Formula), Formula, "0");
	Composer = FinancialReportingServer.SchemaComposer(DCSchema);
	Settings = Composer.GetSettings();
	ExternalSets = New Structure;
	ExternalSets.Insert("OperandsValues", OperandsValues);
	ExternalSets.Insert("ReportIntervals", ReportIntervals);
	
	Try
		IndicatorData = FinancialReportingServer.UnloadDataCompositionResult(DCSchema, Settings, ExternalSets);
	Except
		Info = ErrorInfo();
		ErrorInfoText = Info.Cause.Cause.Description;
		Cancel = True;
		CommonClientServer.MessageToUser(
					ErrorInfoText,
					,
					Field,
					DataPath,);
	EndTry;
	
EndProcedure

Function ReportDetailsParameters(Details, ReportParameters) Export
	
	DetailsParameters = NewReportDetailsParameters();
	FillPropertyValues(DetailsParameters, ReportParameters);
	FillPropertyValues(DetailsParameters.Filter, ReportParameters);
	
	If TypeOf(Details) <> Type("Structure") Then
		Return DetailsParameters;
	EndIf;
	If Details.Property("Filter") Then
		FillPropertyValues(DetailsParameters.Filter, Details.Filter);
	EndIf;
	
	DetailsParameters.Indicator = Details.Indicator;
	If Details.Property("AnalyticalDimension1") Then
		DetailsParameters.Filter.Insert("AnalyticalDimension1", Details.AnalyticalDimension1);
		DetailsParameters.AnalyticalDimensionType = Details.AnalyticalDimensionType;
	EndIf;
	
	If DetailsParameters.Indicator = Undefined Then
		Return DetailsParameters;
	EndIf;
	
	ReportPeriod = New StandardPeriod;
	ReportPeriod.StartDate = Details.StartDate;
	ReportPeriod.EndDate = Details.EndDate;
	DetailsParameters.Insert("ReportPeriod", ReportPeriod);
	
	IndicatorAttributes = IndicatorAttributes(DetailsParameters.Indicator);
	IndicatorAttributes.Insert("Value", ReportParameters.Value);
	If DetailsParameters.Filter.Property("AnalyticalDimension1") Then
		IndicatorAttributes.Insert("AnalyticalDimension1", DetailsParameters.Filter.AnalyticalDimension1);
		IndicatorAttributes.Insert("AnalyticalDimensionType", DetailsParameters.AnalyticalDimensionType);
	EndIf;
	DetailsParameters.Indicator = IndicatorAttributes;
	DetailsParameters.Insert("EmptyRef", Catalogs.FinancialReportsItems.EmptyRef());
	
	// Preparing details reports' settings
	If TypeOf(IndicatorAttributes.Account) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts") Then
		
		DetailsParameters.Filter.Insert("Account", DetailsParameters.Indicator.Account);
		AccountAnalysisSetting = SetManagerialAccountAnalysis(ReportParameters.SettingsAddress, DetailsParameters);
		
	ElsIf TypeOf(IndicatorAttributes.Account) = Type("ChartOfAccountsRef.FinancialChartOfAccounts") Then
		
		AccountAnalysisSetting = SetFinancialAccountAnalysis(DetailsParameters);
		
	EndIf;
	
	DetailsParameters.Insert("AccountAnalysisSetting", AccountAnalysisSetting);
	
	Return DetailsParameters;
	
EndFunction

Function AddExistingOperand(Operand, MainStorageID) Export
	
	ItemStructureAddress = FinancialReportingClientServer.PutItemCopyToTempStorage(
								Operand.LinkedItem,
								MainStorageID);
	OperandData = GetFromTempStorage(ItemStructureAddress);
	NewOperands = New Array;
	If OperandData.ItemType = ItemType("AccountingDataIndicator") Then
		
		NewOperand = AddOperand(Operand, ItemStructureAddress);
		NewOperand.AccountIndicatorDimension = Operand.Account;
		NewOperand.Code = ObjectAttributeValue(NewOperand.AccountIndicatorDimension, "Order");
		NewOperands.Add(NewOperand);
		
	ElsIf OperandData.ItemType = ItemType("UserDefinedFixedIndicator") Then
		
		NewOperand = AddOperand(Operand, ItemStructureAddress);
		NewOperand.AccountIndicatorDimension = Operand.UserDefinedFixedIndicator;
		NewOperand.Code = ObjectAttributeValue(NewOperand.AccountIndicatorDimension, "Code");
		NewOperands.Add(NewOperand);
		
	ElsIf OperandData.ItemType = ItemType("UserDefinedCalculatedIndicator") Then
		
		Formula = AdditionalAttributeValue(OperandData, "Formula");
		For Each FormulaOperand In OperandData.FormulaOperands Do
			
			OperandAddress = FormulaOperand.ItemStructureAddress;
			Data = GetFromTempStorage(OperandAddress);
			NewOperand = AddOperand(Data, OperandAddress);
			NewOperand.ID = FormulaOperand.ID;
			If Data.ItemType = ItemType("AccountingDataIndicator") Then
				NewOperand.AccountIndicatorDimension = AdditionalAttributeValue(Data, "Account");
				NewOperand.Account = NewOperand.AccountIndicatorDimension;
				NewOperand.TotalsType = AdditionalAttributeValue(Data, "TotalsType");
				NewOperand.OpeningBalance = AdditionalAttributeValue(Data, "OpeningBalance");
			ElsIf Data.ItemType = ItemType("UserDefinedFixedIndicator") Then
				NewOperand.AccountIndicatorDimension = AdditionalAttributeValue(Data, "UserDefinedFixedIndicator");
			EndIf;
			
			NewOperands.Add(NewOperand);
			
		EndDo;
	EndIf;
	
	Return New Structure("Formula, NewOperands", Formula, NewOperands);
	
EndFunction

Function GetColor(Name) Export
	
	Return StyleColors[Name];
	
EndFunction

#EndRegion

#Region Private

Procedure CopyItemTables(Source, Recipient)
	
	Recipient.Insert("FormulaOperands",						Source.FormulaOperands.Unload());
	Recipient.Insert("ItemTypeAttributes",					Source.ItemTypeAttributes.Unload());
	Recipient.Insert("TableItems",							Source.TableItems.Unload());
	Recipient.Insert("AdditionalFields",					Source.AdditionalFields.Unload());
	Recipient.Insert("AppearanceItems",						Source.AppearanceItems.Unload());
	Recipient.Insert("AppearanceAppliedRows",				Source.AppearanceAppliedRows.Unload());
	Recipient.Insert("AppearanceAppliedColumns",			Source.AppearanceAppliedColumns.Unload());
	Recipient.Insert("AppearanceItemsFilterFieldsDetails",	Source.AppearanceItemsFilterFieldsDetails.Unload());
	Recipient.Insert("ValuesSources",						Source.ValuesSources.Unload());
	RedefineCacheTablesColumnsType(Recipient);
	
EndProcedure

Procedure RedefineCacheTablesColumnsType(ItemStructure)
	
	TablesStructure = New Structure("FormulaOperands, ItemTypeAttributes, TableItems, 
									|AppearanceAppliedRows, AppearanceAppliedColumns, AppearanceItemsFilterFieldsDetails, ValuesSources");
	
	For Each KeyValue In TablesStructure Do
		
		Table = ItemStructure[KeyValue.Key];
		ItemStructure[KeyValue.Key] = New ValueTable;
		For Each Column In Table.Columns Do
			ItemStructure[KeyValue.Key].Columns.Add(Column.Name);
		EndDo;
		
		CommonClientServer.SupplementTable(Table, ItemStructure[KeyValue.Key]);
		
	EndDo;
	
EndProcedure

Function IndicatorItemEmptyTable()
	
	Result = New ValueTable;
	Result.Columns.Add("Indicator",	New TypeDescription("CatalogRef.FinancialReportsItems"));
	Result.Columns.Add("Note",		New TypeDescription("String", , New StringQualifiers(100)));
	Result.Columns.Add("RowCode",	New TypeDescription("String", , New StringQualifiers(20)));
	Result.Columns.Add("StartDate",	New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
	Result.Columns.Add("EndDate",	New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
	Result.Columns.Add("Value",		Common.TypeDescriptionNumber(15, 2));
	Return Result;
	
EndFunction

Function NewReportDetailsParameters()
	
	Result = New Structure;
	Result.Insert("ReportType");
	Result.Insert("ReportsSet");
	Result.Insert("Indicator");
	Result.Insert("Resource");
	Result.Insert("Value");
	Result.Insert("AnalyticalDimensionType");
	Result.Insert("AmountsInThousands");
	
	Filter = New Structure("Company, BusinessUnit, LineOfBusiness");
	Result.Insert("Filter", Filter);
	
	Return Result;
	
EndFunction

Function IndicatorAttributes(Val Indicator)
	
	ItemData = FinancialReportingClientServer.ReportItemStructure();
	Attributes = "Account, UserDefinedFixedIndicator, Formula";
	If ValueIsFilled(Indicator.LinkedItem) Then
		Indicator = Indicator.LinkedItem;
	EndIf;
	
	ItemTables = "ItemTypeAttributes, ValuesSources, FormulaOperands, TableItems, AdditionalFields,
				|AppearanceItems, AppearanceAppliedRows, AppearanceAppliedColumns, AppearanceItemsFilterFieldsDetails";
	
	AdditionalAttributes = AdditionalAttributesValues(Indicator, Attributes);
	FillPropertyValues(ItemData, Indicator,,ItemTables);
	For Each Attribute In AdditionalAttributes Do
		ItemData.Insert(Attribute.Key, Attribute.Value);
	EndDo;
	
	Return ItemData;
	
EndFunction

Function SetManagerialAccountAnalysis(Address, Parameters)
	
	// Details report settings
	ReportSetting = New Structure("SettingsAddress", Address);
	
	AccountAnalysis = New Structure("AccountAnalysis");
	DetailsData = New Structure("DetailsSettings", AccountAnalysis);
	UserSettings = New DataCompositionUserSettings;
	UserFilter = UserSettings.Items.Add(Type("DataCompositionFilter"));
	UserFilter.UserSettingID = "Filter";
	
	// Accounting data indicator filter
	FilterSettings = Parameters.Indicator.AdditionalFilter.Get();
	If FilterSettings <> Undefined Then
		FinancialReportingServer.CopyFilter(
				FilterSettings.Filter,
				UserFilter,
				True);
	EndIf;
	
	// Report attributes
	ReportAttributes = UserSettings.AdditionalProperties;
	ReportAttributes.Insert("IndicatorAcc", True);
	ReportAttributes.Insert("DetailsMode", True);
	ReportAttributes.Insert("BeginOfPeriod", Parameters.ReportPeriod.StartDate);
	ReportAttributes.Insert("EndOfPeriod", Parameters.ReportPeriod.EndDate);
	
	For Each Parameter In Parameters.Filter Do
		If ValueIsFilled(Parameter.Value) Then
			ReportAttributes.Insert(Parameter.Key, Parameter.Value);
			If (Parameter.Key = "Company" Or Parameter.Key = "BusinessUnit" Or Parameter.Key = "LineOfBusiness")
				And TypeOf(Parameter.Value) = Type("Array") Then
				ReportAttributes.Insert(Parameter.Key, Parameter.Value[0]);
			EndIf;
		EndIf;
	EndDo;
	
	DetailsData.DetailsSettings.AccountAnalysis = UserSettings;
	PutToTempStorage(DetailsData, Address);
	
	Return ReportSetting;
	
EndFunction

Function SetFinancialAccountAnalysis(Val Parameters)
	
	SettingsComposer = New DataCompositionSettingsComposer;
	Return SettingsComposer;
	
EndFunction

Function ItemType(ItemTypeName)
	
	Return Enums.FinancialReportItemsTypes[ItemTypeName];
	
EndFunction

Function AddOperand(OperandData, ItemStructureAddress)
	
	NewOperand = FinancialReportingClientServer.NewOperandData();
	FillPropertyValues(NewOperand, OperandData, , "LinkedItem");
	NewOperand.ItemStructureAddress = ItemStructureAddress;
	NewOperand.IsLinked = False;
	NewOperand.NonstandardPicture = FinancialReportingCached.NonstandardPicture(OperandData.ItemType);
	
	Return NewOperand;
	
EndFunction

#EndRegion