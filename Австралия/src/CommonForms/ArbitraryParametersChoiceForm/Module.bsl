
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("CurrentValue"			, CurrentValue);
	Parameters.Property("DrCr"					, CurrentDrCr);
	Parameters.Property("FormulaMode"			, FormulaMode);
	Parameters.Property("ValueMode"				, ValueMode);
	Parameters.Property("SwitchFormulaMode"		, SwitchFormulaMode);
	Parameters.Property("ModeSwitchAllowed"		, ModeSwitchAllowed);
	Parameters.Property("ValueModeSwitchAllowed", ValueModeSwitchAllowed);
	Parameters.Property("ChartOfAccounts" 		, ChartOfAccounts);
	
	If Parameters.Property("AttributeName") Then
		
		AdditionalParameter = "";
		If Parameters.AttributeID = "AnalyticalDimensionValue" Or Parameters.AttributeID = "DefaultAccountFilter" Then
			
			AdditionalParameter = Parameters.AttributeNameType;
			Title = StrTemplate(NStr("en = 'Select %1'; ru = 'Укажите %1';pl = 'Wybierz %1';es_ES = 'Seleccionar %1';es_CO = 'Seleccionar %1';tr = '%1 seç';it = 'Selezionare %1';de = '%1 auswählen'"), Parameters.AttributeNameType);
			
		ElsIf Upper(Parameters.AttributeID) = Upper("amount") Then
			
			Title = NStr("en = 'Select amount (presentation currency)'; ru = 'Укажите сумму (валюта представления отчетности)';pl = 'Wybierz wartość (waluta prezentacji)';es_ES = 'Seleccionar el importe (moneda de presentación)';es_CO = 'Seleccionar el importe (moneda de presentación)';tr = 'Tutar seç (finansal tablo para birimi)';it = 'Selezionare importo (valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung) auswählen'");
			
		ElsIf Upper(Parameters.AttributeID) = Upper("account") Then
			
			AdditionalParameter = Parameters.NameAdding;
			Title = StrTemplate(NStr("en = 'Select %1'; ru = 'Укажите %1';pl = 'Wybierz %1';es_ES = 'Seleccionar %1';es_CO = 'Seleccionar %1';tr = '%1 seç';it = 'Selezionare %1';de = '%1 auswählen'"), Parameters.AttributeName);
			
		ElsIf Upper(Parameters.AttributeID) = Upper("quantity")
			Or Upper(Parameters.AttributeID) = Upper("currency")
			Or Upper(Parameters.AttributeID) = Upper("AmountCur") Then
			
			AdditionalParameter = Parameters.IDAdding;
			Title = StrTemplate(NStr("en = 'Select %1'; ru = 'Укажите %1';pl = 'Wybierz %1';es_ES = 'Seleccionar %1';es_CO = 'Seleccionar %1';tr = '%1 seç';it = 'Selezionare %1';de = '%1 auswählen'"), Parameters.AttributeName);
			
		Else
			
			Title = StrTemplate(NStr("en = 'Select %1'; ru = 'Укажите %1';pl = 'Wybierz %1';es_ES = 'Seleccionar %1';es_CO = 'Seleccionar %1';tr = '%1 seç';it = 'Selezionare %1';de = '%1 auswählen'"), Parameters.AttributeName);
			
		EndIf;
		
		Items.DecorationFormTooltip.Title =
			MessagesToUserClientServer.GetTooltip(Parameters.AttributeID, AdditionalParameter, False);
		Items.DecorationValueFormTooltip.Title =
			MessagesToUserClientServer.GetTooltip(Parameters.AttributeID, AdditionalParameter, True);
			
		If ModeSwitchAllowed Then
			Items.DecorationFormulaFormTooltip.Title =
				 MessagesToUserClientServer.GetFormulaTooltip(Parameters.AttributeID, AdditionalParameter);
		EndIf;
		
		If Upper(Parameters.AttributeID) = Upper("AmountCur") Or Upper(Parameters.AttributeID) = Upper("amount") Then
			
			Items.OperatorsDescription.Title = "Operations";
			
		EndIf;
		
		AttributeName	= Parameters.AttributeName;
		AttributeID		= Parameters.AttributeID;
		
	EndIf;
	
	AttributesTable			= WorkWithArbitraryParameters.InitParametersTable();
	NestedAttributesTable	= WorkWithArbitraryParameters.InitNestedAttributesTable();
	
	If Parameters.Property("ExcludedFields") Then
		ExcludedFieldsArray = Parameters.ExcludedFields;
	Else
		ExcludedFieldsArray = New Array;
	EndIf;
	
	If ValueMode Then
		AttributeValue = CurrentValue;
	EndIf;
	
	If ModeSwitchAllowed Then
		
		SwitchFormulaModeChoiceList = Items.SwitchFormulaMode.ChoiceList;
		SwitchFormulaModeChoiceList.Clear();
		SwitchFormulaModeChoiceList.Add(0, NStr("en = 'Data field'; ru = 'Поле данных';pl = 'Pole danych';es_ES = 'Campo de datos';es_CO = 'Campo de datos';tr = 'Veri alanı';it = 'Campo dati';de = 'Datenfeld'"));
		
		If ValueModeSwitchAllowed Then
			SwitchFormulaModeChoiceList.Add(2, NStr("en = 'Value'; ru = 'Значение';pl = 'Wartość';es_ES = 'Valor';es_CO = 'Valor';tr = 'Değer';it = 'Valore';de = 'Wert'"));
		Else
			SwitchFormulaModeChoiceList.Add(1, NStr("en = 'Formula'; ru = 'Формула';pl = 'Formuła';es_ES = 'Fórmula';es_CO = 'Fórmula';tr = 'Formül';it = 'Formula';de = 'Formel'"));
		EndIf;
		
	EndIf;
	
	If Parameters.Property("FillDocumentType") Then
		
		If Parameters.Property("ChartOfAccounts") And ValueIsFilled(Parameters.ChartOfAccounts) Then
			WorkWithArbitraryParameters.GetRecordersListByCoA(AttributesTable, Parameters.ChartOfAccounts);
		ElsIf Parameters.Property("ChartOfAccounts") Then
			WorkWithArbitraryParameters.GetRecordersList(AttributesTable);
		Else
			WorkWithArbitraryParameters.GetAllDocumentsTable(AttributesTable);
		EndIf;
		
		Items.ParametersTreeExpandAll.Visible	 = False;
		Items.ParametersTreeCollapseAll.Visible	 = False;
	
	ElsIf Parameters.Property("FillCatalogsFilter") Then
		
		WorkWithArbitraryParameters.GetAvailableCatalogsTable(AttributesTable);
		WorkWithArbitraryParameters.GetAvailableEnumsTable(AttributesTable);
		
	ElsIf Parameters.Property("FillDataSources") Then
		
		WorkWithArbitraryParameters.GetAvailableDataSourcesTable(AttributesTable, Parameters.DocumentType);
		
	ElsIf Parameters.Property("FillCompanies") Then
		
		WorkWithArbitraryParameters.SupplementParametersTableWithDataSourceAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DataSource,
			Parameters.DocumentType,
			New TypeDescription("CatalogRef.Companies"));
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAdditionalAttributes(
			AttributesTable, 
			Parameters.DocumentType,
			New TypeDescription("CatalogRef.Companies"));
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DocumentType,
			New TypeDescription("CatalogRef.Companies"));
		
	ElsIf Parameters.Property("FillCurrencies") Then
		
		WorkWithArbitraryParameters.SupplementParametersTableWithDataSourceAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DataSource,
			Parameters.DocumentType,
			New TypeDescription("CatalogRef.Currencies"));
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAdditionalAttributes(
			AttributesTable, 
			Parameters.DocumentType,
			New TypeDescription("CatalogRef.Currencies"));
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DocumentType,
			New TypeDescription("CatalogRef.Currencies"));
		
	ElsIf Parameters.Property("FillAmounts") Then
		
		WorkWithArbitraryParameters.SupplementParametersTableWithDataSourceAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DataSource,
			Parameters.DocumentType,
			,
			True);
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAdditionalAttributes(
			AttributesTable, 
			Parameters.DocumentType,
			,
			True);
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DocumentType,
			,
			True);
		
		IsAmountSelection = True;
		
	ElsIf Parameters.Property("FillPeriods") Then
		
		DataTypeRestriction = New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime));
		
		WorkWithArbitraryParameters.SupplementParametersTableWithDataSourceAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DataSource,
			Parameters.DocumentType,
			DataTypeRestriction);
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAdditionalAttributes(
			AttributesTable, 
			Parameters.DocumentType,
			DataTypeRestriction);
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DocumentType,
			DataTypeRestriction);
		
		IsPeriodSelection = True;
		
	ElsIf Parameters.Property("FillByTypeDescription") Then
		
		WorkWithArbitraryParameters.SupplementParametersTableWithDataSourceAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DataSource,
			Parameters.DocumentType,
			Parameters.TypeDescription,
			,
			ExcludedFieldsArray);
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAdditionalAttributes(
			AttributesTable, 
			Parameters.DocumentType,
			Parameters.TypeDescription);
			
		WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAttributes(
			AttributesTable,
			NestedAttributesTable,
			Parameters.DocumentType,
			Parameters.TypeDescription,
			,
			ExcludedFieldsArray);
			
		Items.AttributeValue.TypeRestriction = Parameters.TypeDescription;
		
	ElsIf Parameters.Property("FillAccounts") Then
		
		WorkWithArbitraryParameters.GetAvailableAccountsList(AttributesTable, Parameters);
		
	ElsIf Parameters.Property("FillExtDimensions") Then
		
		WorkWithArbitraryParameters.GetDimensionsList(AttributesTable, NestedAttributesTable, Parameters);
		
	ElsIf Parameters.Property("FillExtDimensionsByAccount") Then
		
		WorkWithArbitraryParameters.GetDimensionsListByAccount(AttributesTable, NestedAttributesTable, Parameters);
		
	Else
		
		WorkWithArbitraryParameters.SupplementParametersTableWithAP(AttributesTable, NestedAttributesTable);
		WorkWithArbitraryParameters.SupplementParametersTableWithConstants(AttributesTable, NestedAttributesTable);
		
		If Parameters.Property("DocumentType") Then
			WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAttributes(
				AttributesTable,
				NestedAttributesTable,
				Parameters.DocumentType);
			WorkWithArbitraryParameters.SupplementParametersTableWithDocumentsAdditionalAttributes(
				AttributesTable,
				Parameters.DocumentType);
		EndIf;
		If Parameters.Property("DataSource") And Parameters.Property("DocumentType") Then
			WorkWithArbitraryParameters.SupplementParametersTableWithDataSourceAttributes(
				AttributesTable,
				NestedAttributesTable,
				Parameters.DataSource,
				Parameters.DocumentType);
		EndIf;
		
	EndIf;
	
	ValueToFormAttribute(AttributesTable		, "ParametersDataTable");
	ValueToFormAttribute(NestedAttributesTable	, "NestedParametersDataTable");

	InitializeTree();
	
	Items.DecorationFormTooltip.Visible = Items.DecorationFormTooltip.Title <> "";
	
	OperandBegin	= PriceGenerationFormulaServerCall.StringBeginOperand();
	OperandEnd		= PriceGenerationFormulaServerCall.StringEndOperand();
	If FormulaMode Then 
		
		FillOperatorsTree();
		
		Formula = CurrentValue;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(CurrentValue) And Not FormulaMode Then
		
		Items.ParametersTree.CurrentRow = FindValueInTree(ParametersTree.GetItems(), CurrentValue, CurrentDrCr);
		
	ElsIf Not ValueIsFilled(CurrentValue) 
		And Not FormulaMode
		And (Upper(AttributeID) = Upper("Period")
			Or Upper(AttributeID) = Upper("Quantity")
			Or Upper(AttributeID) = Upper("Currency")
			Or Upper(AttributeID) = Upper("AmountCur")
			Or Upper(AttributeID) = Upper("Amount")
			Or Upper(AttributeID) = Upper("DefaultAccountFilter")
			Or Upper(AttributeID) = Upper("AnalyticalDimensionValue")) Then
		
		RebuildTree("ParametersTree", 1);
		
	EndIf;
	
	SetFormElementsVisibility();
	
	ValueModeTemp = Not ValueMode;
	ThisObject.AttachIdleHandler("ChangeVisible", 0.01, True);
	
EndProcedure

&AtClient
Procedure ChangeVisible()
	
	If ValueMode <> ValueModeTemp Then
		
		If ValueMode Then
			Items.Header.Visible			= True;
			Items.FilterString.Visible		= True;
			Items.GroupValue.Visible		= False;
		Else
			Items.Header.Visible			= False;
			Items.FilterString.Visible		= False;
			Items.GroupValue.Visible		= True;
		EndIf;
		
		ValueModeTemp = Not ValueModeTemp;
		
		ThisObject.AttachIdleHandler("ChangeVisible", 0.01, True);
		
	Else
		
		SetFormElementsVisibility();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetFormElementsVisibility()
	
	Items.DecorationFormulaFormTooltip.Visible	= FormulaMode;
	Items.GroupFormula.Visible					= FormulaMode;
	Items.GroupHeaderRight.Visible				= FormulaMode;
	Items.FormCheckFormula.Visible				= FormulaMode;
	Items.Header.Visible						= Not ValueMode;
	Items.FilterString.Visible					= Not ValueMode;
	Items.GroupValue.Visible					= ValueMode;
	
	Items.ParametersTree.Header				= FormulaMode;
	Items.GroupBarParametersTree.Visible	= Not FormulaMode;
	
	Items.SwitchFormulaMode.Visible	= ModeSwitchAllowed;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ParametersTreeSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;

	CurrentData = Items.ParametersTree.CurrentData;
	
	If Not ValueIsFilled(CurrentData.Field) Or CurrentData.RestrictedByType Then
		Return;
	EndIf;
	
	If FormulaMode Then
		
		InsertedText = OperandBegin + CurrentData.Field + OperandEnd;
		InsertTextToFormula(InsertedText);
		
	Else
		
		ResultStructure = New Structure("Field, ValueType, Synonym, DrCr");
		FillPropertyValues(ResultStructure, CurrentData);
		
		NotifyChoice(ResultStructure);
	
	EndIf;
	
EndProcedure

&AtClient
Procedure ParametersTreeDragStart(Item, DragParameters, Perform)
	
	FillDragParameters(Item, DragParameters);
	
EndProcedure

&AtClient
Procedure TreeInitClient()

	InitializeTree();

	For Each TreeBranch In ParametersTree.GetItems() Do
		Items.ParametersTree.Expand(TreeBranch.GetId());
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearSearchString(Command)
	
	FilterString = Undefined;
	InitializeTree();
	
EndProcedure


#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Confirm(Command)
	
	If FormulaMode Then
		
		CloseResult = New Structure;
		CloseResult.Insert("ClosedOK"	, True);
		CloseResult.Insert("Field"		, Formula);
		CloseResult.Insert("Synonym"	, Formula);
		CloseResult.Insert("DrCr"		, CurrentDrCr);
		
		Close(CloseResult);
		
	ElsIf ValueMode Then
		
		CloseResult = New Structure;
		CloseResult.Insert("ClosedOK"	, True);
		CloseResult.Insert("Field"		, AttributeValue);
		CloseResult.Insert("Synonym"	, AttributeValue);
		CloseResult.Insert("DrCr"		, CurrentDrCr);
		
		Close(CloseResult);
		
	Else
		
		CurrentData = Items.ParametersTree.CurrentData;
		If CurrentData = Undefined
			Or Not ValueIsFilled(CurrentData.Field)
			Or CurrentData.RestrictedByType Then
			ShowMessageBox( , NStr("en = 'Cannot select a group of items. Select an item from the group. Then try again.'; ru = 'Не удалось выбрать группу элементов. Выберите элемент из группы и повторите попытку.';pl = 'Nie można wybrać grupy pozycji. Wybierz pozycję z grupy. Zatem spróbuj ponownie.';es_ES = 'No se puede seleccionar un grupo de artículos. Seleccione un artículo del grupo. Inténtelo de nuevo.';es_CO = 'No se puede seleccionar un grupo de artículos. Seleccione un artículo del grupo. Inténtelo de nuevo.';tr = 'Öğe grubu seçilemiyor. Gruptan bir öğe seçip tekrar deneyin.';it = 'Impossibile selezionare un gruppo di elementi. Selezionare un elemento dal gruppo, poi riprovare.';de = 'Fehler beim Auswählen einer Gruppe von Elementen. Wählen Sie ein Element aus der Gruppe aus. Dann versuchen Sie erneut.'"));
			Return;
		EndIf;
		
		ResultStructure = New Structure("Field, ValueType, Synonym, DrCr");
		FillPropertyValues(ResultStructure, CurrentData);
		
		NotifyChoice(ResultStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterStringOnChange(Item)
	
	InitializeTree();
	
	For Each TreeBranch In ParametersTree.GetItems() Do
		Items.ParametersTree.Expand(TreeBranch.GetId(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure FilterStringClearing(Item, StandardProcessing)
	
	InitializeTree();
	
EndProcedure

&AtClient
Procedure FilterStringOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	AttachIdleHandler("TreeInitClient", 0.1, True);
	
EndProcedure

&AtClient
Procedure SwitchFormulaModeOnChange(Item)
	
	FormulaMode	 = (SwitchFormulaMode = 1);
	ValueMode	 = (SwitchFormulaMode = 2);
	
	SetFormElementsVisibility();
	
	If Operators.GetItems().Count() = 0 Then
		FillOperatorsTree();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region FormulasEventsHandlers

&AtClient
Procedure OperatorsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRowData = Items.Operators.CurrentData;
	If CurrentRowData = Undefined Or Not ValueIsFilled(CurrentRowData.Operator) Then
		Return;
	EndIf;
	
	AddingTextParameters = BeforeAddingTextInFormula(CurrentRowData.Operator);
	
	If Not AddingTextParameters.Cancel Then
		
		InsertTextToFormula(AddingTextParameters.InsertableText, AddingTextParameters.ReplaceFormulaText);
		
	EndIf;

EndProcedure

&AtClient
Procedure OperatorsDragEnd(Item, DragParameters, StandardProcessing)
	
	If DragParameters.Value.Count() < 0 Then
		Return;
	EndIf;
	
	CurrentRowData = DragParameters.Value[0];
	
	If CurrentRowData = Undefined Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	InsertedText = CurrentRowData.Operator;
	
	If TrimAll(InsertedText) = "%1"
		Or TrimAll(InsertedText) = "%5"
		Or TrimAll(InsertedText) = "%20"
		Or TrimAll(InsertedText) = "%50" Then
		
		OperandData = Items.Operands.CurrentData;
		
		If OperandData = Undefined Or IsBlankString(OperandData.Operand) Then
			
			TextMessage = NStr("en ='Specify the type of prices from which you want to calculate the percentage'; ru = 'Укажите тип цен, на основании которых вы хотите рассчитать процентное соотношение';pl = 'Wybierz rodzaj ceny z tych, które chcesz przeliczyć w procentach';es_ES = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';es_CO = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';tr = 'Yüzdesini hesaplamak istediğiniz fiyat türünü belirtin';it = 'Specifica il tipo di prezzo da cui volete calcolare la percentuale';de = 'Geben Sie den Preistyp an, aus denen Sie den Prozentsatz berechnen möchten.'");
			CommonClientServer.MessageToUser(TextMessage, , "Operands");
			
			Return;
			
		Else
			
			PresentationNumber = StrReplace(InsertedText, "%", "");
			InsertedText = " + ([" + OperandData.Operand + "] / 100 * " + PresentationNumber + ".0)";
			
		EndIf;
		
	EndIf;
	
	InsertTextToFormula(InsertedText);

EndProcedure

&AtClient
Procedure FormulaOnChange(Item)
	
	OperatorsAllowingComma = New Array;
	OperatorsAllowingComma.Add("MIN");
	OperatorsAllowingComma.Add("MAX");
	OperatorsAllowingComma.Add("ROUND");
	OperatorsAllowingComma.Add("BEGINOFPERIOD");
	OperatorsAllowingComma.Add("ENDOFPERIOD");
	
	ValidCommasCount = 0;
	For Each Item In OperatorsAllowingComma Do
		
		ValidCommasCount = ValidCommasCount + StrOccurrenceCount(Upper(Formula), Upper(Item));
		
	EndDo;
	
	CommasCount = StrOccurrenceCount(Formula, ",");
	If CommasCount > ValidCommasCount Then
		
		TextMessage = NStr("en ='To specify the fractional part, you must use a point, not a comma.'; ru = 'Для указания десятичной части используйте точку, а не запятую.';pl = 'Do podania części dziesiętnej, należy używać kropki, nie przecinka';es_ES = 'Para especificar la parte fraccionaria, debe utilizar un punto, no una coma.';es_CO = 'Para especificar la parte fraccionaria, debe utilizar un punto, no una coma.';tr = 'Kesirli kısmı belirtmek için virgül değil, bir nokta kullanmanız gerekir.';it = 'Per specificare la parte frazionaria è necessario utilizzare un punto al posto della virgola.';de = 'Um den Bruchteil anzugeben, müssen Sie einen Punkt und kein Komma verwenden.'");
		
		CommonClientServer.MessageToUser(TextMessage, , "Formula");
		
	EndIf;

EndProcedure
	
#EndRegion

&AtClient
Procedure FillDragParameters(Item, DragParameters)
	
	CurrentRowData = Items.ParametersTree.CurrentData;
	If Not ValueIsFilled(CurrentRowData.Field) Then
		ShowMessageBox( , NStr("en = 'Cannot select group. Select individual item within group, then try again.'; ru = 'Не удалось выбрать группу. Выберите элемент из группы и повторите попытку.';pl = 'Nie można wybrać grupy. Wybierz pojedynczy element w grupie, następnie spróbuj ponownie.';es_ES = 'No se puede seleccionar el grupo. Seleccione un artículo individual dentro del grupo e inténtelo de nuevo.';es_CO = 'No se puede seleccionar el grupo. Seleccione un artículo individual dentro del grupo e inténtelo de nuevo.';tr = 'Grup seçilemiyor. Gruptan tek bir öğe seçip tekrar deneyin.';it = 'Impossibile selezionare il gruppo. Selezionare un elemento singolo all''interno del gruppo, poi riprovare.';de = 'Fehler beim Auswählen der Gruppe. Wählen Sie ein individuelles Element in der Gruppe, dann versuchen Sie erneut.'"));
		Return;
	EndIf;
	DragParameters.Value = OperandBegin + CurrentRowData.Field + OperandEnd;
	
EndProcedure

&AtClient
Function BeforeAddingTextInFormula(Val InsertableText)
	
	AddingTextParameters = New Structure("InsertableText, ReplaceFormulaText, Cancel", InsertableText, False, False);
	
	OperandData = Items.ParametersTree.CurrentData;
	
	If TrimAll(InsertableText) = "%1"
		Or TrimAll(InsertableText) = "%5"
		Or TrimAll(InsertableText) = "%20"
		Or TrimAll(InsertableText) = "%50" Then
		
		If OperandData = Undefined Or IsBlankString(OperandData.Field) Then
			
			TextMessage = NStr("en ='Specify the type of prices from which you want to calculate the percentage'; ru = 'Укажите тип цен, на основании которых вы хотите рассчитать процентное соотношение';pl = 'Wybierz rodzaj ceny z tych, które chcesz przeliczyć w procentach';es_ES = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';es_CO = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';tr = 'Yüzdesini hesaplamak istediğiniz fiyat türünü belirtin';it = 'Specifica il tipo di prezzo da cui volete calcolare la percentuale';de = 'Geben Sie den Preistyp an, aus denen Sie den Prozentsatz berechnen möchten.'");
			CommonClientServer.MessageToUser(TextMessage, , "Operands");
			
			AddingTextParameters.Cancel = True;
			
			Return AddingTextParameters;
			
		Else
			
			PresentationNumber = StrReplace(InsertableText, "%", "");
			AddingTextParameters.InsertableText = StrTemplate(" + (%1", OperandBegin)
				+ OperandData.Field
				+ StrTemplate("%1 / 100 * ", OperandEnd)
				+ PresentationNumber
				+ ".0)";
			
		EndIf;
		
	EndIf;
	
	If TrimAll(AddingTextParameters.InsertableText) = "If" Then
		
		ConditionalOperatorFirstValue = "<?>";
		If Not IsBlankString(Formula) Then
			
			ConditionalOperatorFirstValue = Formula;
			Formula = "";
			AddingTextParameters.ReplaceFormulaText = True;
			
		ElsIf OperandData <> Undefined And Not IsBlankString(OperandData.Field) Then
			
			ConditionalOperatorFirstValue = OperandBegin + OperandData.Field + OperandEnd;
			
		EndIf;
		
		AddingTextParameters.InsertableText = StrTemplate("#IF <Condition>%1%2#THEN %3%1%2#ELSE <?>%1#ENDIF",
			Chars.LF,
			Chars.Tab,
			ConditionalOperatorFirstValue);
		
	EndIf;
	
	Return AddingTextParameters;
	
EndFunction

&AtClient
Procedure InsertTextToFormula(InsertableText, ReplaceFormulaText = False)
	
	If IsBlankString(InsertableText) Then
		
		Return;
		
	EndIf;
	
	If ReplaceFormulaText Then
		
		Formula = InsertableText;
		Return;
		
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		Formula = Formula + InsertableText;
		
	Else
		
		RowBegin	= 0;
		RowEnd		= 0;
		ColumnBegin	= 0;
		ColumnEnd	= 0;
		
		Items.Formula.GetTextSelectionBounds(RowBegin, ColumnBegin, RowEnd, ColumnEnd);
		If (ColumnEnd = ColumnBegin)  
			And (ColumnEnd + StrLen(InsertableText)) > (Items.Formula.Width / 8) Then
			
			Items.Formula.SelectedText = "";
			
		EndIf;
		
		Items.Formula.SelectedText = InsertableText;
		
	EndIf;
	
	CurrentItem = Items.Formula;
	
EndProcedure

&AtServer
Procedure FillOperatorsTree()
	
	OperatorsTree = FormAttributeToValue("Operators", Type("ValueTree"));
	
	AddUnavailable = False; // For future use
	
	If IsAmountSelection Then
		
		RowsGroup				= OperatorsTree.Rows.Add();
		RowsGroup.Description	= NStr("en ='ARITHMETIC OPERATORS'; ru = 'АРИФМЕТИЧЕСКИЕ ОПЕРАТОРЫ';pl = 'OPERATORY ARYTMETYCZNE';es_ES = 'OPERADORES ARITMÉTICOS';es_CO = 'OPERADORES ARITMÉTICOS';tr = 'ARİTMETİK OPERATÖRLER';it = 'OPERATORI ARITMETICI';de = 'ARITHMETISCHE OPERATOREN'");
		RowsGroup.Picture		= 1;
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Addition'; ru = 'Сложение';pl = 'Dodatek';es_ES = 'Adición';es_CO = 'Adición';tr = 'Toplama';it = 'Addizione';de = 'Hinzunahme'") + " ""+""";
		NewRow.Operator			= " + ";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Subtraction'; ru = 'Вычитание';pl = 'Odejmowanie';es_ES = 'Sustracción';es_CO = 'Sustracción';tr = 'Çıkarma';it = 'Sottrazione';de = 'Subtraktion'") + " ""-""";
		NewRow.Operator			= " - ";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Multiplication'; ru = 'Умножение';pl = 'Mnożenie';es_ES = 'Multiplicación';es_CO = 'Multiplicación';tr = 'Çarpma';it = 'Moltiplicazione';de = 'Multiplikation'") + " ""*""";
		NewRow.Operator			= " * ";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Division'; ru = 'Деление';pl = 'Dzielenie';es_ES = 'División';es_CO = 'División';tr = 'Bölme';it = 'Divisione';de = 'Division'") + " ""/""";
		NewRow.Operator			= " / ";
		
	EndIf;
	
	If IsPeriodSelection Then
		
		RowsGroup				= OperatorsTree.Rows.Add();
		RowsGroup.Description	= NStr("en ='DATE FUNCTIONS'; ru = 'ФУНКЦИИ ДАТЫ';pl = 'FUNKCJE DATY';es_ES = 'FUNCIONES DE FECHA';es_CO = 'FUNCIONES DE FECHA';tr = 'TARİH FONKSİYONLARI';it = 'FUNZIONI DATA';de = 'DATUMSFUNKTIONEN'");
		RowsGroup.Picture		= 1;
		
		NewRow	 				= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Beginning of this month'; ru = 'Начало месяца';pl = 'Początek bieżącego miesiąca';es_ES = 'Principios del mes';es_CO = 'Principios del mes';tr = 'Bu ayın başı';it = 'Inizio del mese';de = 'Beginn dieses Monats'");
		NewRow.Operator			= "BEGINOFPERIOD(<?>, MONTH)";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='End of this month'; ru = 'Конца месяца';pl = 'Koniec bieżącego miesiąca';es_ES = 'Fin de mes';es_CO = 'Fin de mes';tr = 'Bu ayın sonu';it = 'Fine del mese';de = 'Ende dieses Monats'");
		NewRow.Operator			= "ENDOFPERIOD(<?>, MONTH)";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Beginning of this year'; ru = 'Начало года';pl = 'Początek bieżącego roku';es_ES = 'A inicios de este año';es_CO = 'A inicios de este año';tr = 'Bu yılın başı';it = 'Inizio di quest''anno';de = 'Beginn dieses Jahres'");
		NewRow.Operator			= "BEGINOFPERIOD(<?>, YEAR)";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='End of this year'; ru = 'Конец года';pl = 'Koniec bieżącego roku';es_ES = 'A finales de este año';es_CO = 'A finales de este año';tr = 'Bu yılın sonu';it = 'Fine di quest''anno';de = 'Ende dieses Jahres'");
		NewRow.Operator			= "ENDOFPERIOD(<?>, YEAR)";
		
	EndIf;

	If AddUnavailable Then
		RowsGroup				= OperatorsTree.Rows.Add();
		RowsGroup.Description	= NStr("en ='LOGICAL OPERATORS'; ru = 'ЛОГИЧЕСКИЕ ОПЕРАТОРЫ';pl = 'OPERATORY LOGICZNE';es_ES = 'OPERADORES LÓGICOS';es_CO = 'OPERADORES LÓGICOS';tr = 'MANTIKSAL OPERATÖRLER';it = 'OPERATORI LOGICI';de = 'LOGISCHE OPERATOREN'");
		RowsGroup.Picture		= 1;
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='If...Else...EndIf'; ru = 'Если...Иначе...КонецЕсли';pl = 'If...Else...EndIf';es_ES = 'Si...Más...EndIf';es_CO = 'Si...Más...EndIf';tr = 'If...Else...EndIf';it = 'If...Else...Endif';de = 'If...Else...EndIf'");
		NewRow.Operator			= "If"; 
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= " > ";
		NewRow.Operator			= " > ";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= " >= ";
		NewRow.Operator			= " >= ";
		
		NewRow					= RowsGroup.Rows.Add();
		NewRow.Description		= " < ";
		NewRow.Operator			= " < ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= " <= ";
		NewRow.Operator			= " <= ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= " = ";
		NewRow.Operator			= " = ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= " <> ";
		NewRow.Operator			= " <> ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='AND'; ru = 'И';pl = 'AND';es_ES = 'Y';es_CO = 'Y';tr = 'AND';it = 'AND';de = 'UND'");
		NewRow.Operator			= " AND ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='OR'; ru = 'ИЛИ';pl = 'OR';es_ES = 'O';es_CO = 'O';tr = 'OR';it = 'OR';de = 'ODER'");
		NewRow.Operator			= " OR ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='NOT'; ru = 'НЕ';pl = 'NOT';es_ES = 'NO';es_CO = 'NO';tr = 'NOT';it = 'NOT';de = 'NICHT'");
		NewRow.Operator			= " NOT ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='TRUE'; ru = 'ИСТИНА';pl = 'TRUE';es_ES = 'VERDADERO';es_CO = 'VERDADERO';tr = 'TRUE';it = 'TRUE';de = 'TRUE'");
		NewRow.Operator			= " TRUE ";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='FALSE'; ru = 'ЛОЖЬ';pl = 'FALSE';es_ES = 'FALSO';es_CO = 'FALSO';tr = 'FALSE';it = 'FALSE';de = 'FALSE'");
		NewRow.Operator			= " FALSE ";
		
		NewRow		 			= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Opening bracket'; ru = 'Открывающая скобка';pl = 'Nawias otwierający';es_ES = 'Paréntesis de apertura';es_CO = 'Paréntesis de apertura';tr = 'Açılış parantezi';it = 'Apertura parentesi';de = 'Öffnende Klammer'") + " ""(""";
		NewRow.Operator			= " (";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Closing bracket'; ru = 'Закрывающая скобка';pl = 'Nawias zamykający';es_ES = 'Paréntesis de cierre';es_CO = 'Paréntesis de cierre';tr = 'Kapanış parantezi';it = 'Chiusura parentesi';de = 'Schließende Klammer'") + " "")""";
		NewRow.Operator			= ") ";
		
		RowsGroup 				= OperatorsTree.Rows.Add();
		RowsGroup.Description	= NStr("en ='FUNCTIONS'; ru = 'ФУНКЦИИ';pl = 'FUNKCJE';es_ES = 'FUNCIONES';es_CO = 'FUNCIONES';tr = 'İŞLEVLER';it = 'FUNZIONI';de = 'FUNKTIONEN'");
		RowsGroup.Picture		= 1;
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Maximum'; ru = 'Максимум';pl = 'Maksimum';es_ES = 'Máximo';es_CO = 'Máximo';tr = 'Maksimum';it = 'Massimo';de = 'Maximum'");
		NewRow.Operator			= " MAX(<?>,<?>)";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Minimum'; ru = 'Минимум';pl = 'Minimum';es_ES = 'Mínimo';es_CO = 'Mínimo';tr = 'Minimum';it = 'Minimo';de = 'Minimum'");
		NewRow.Operator			= " MIN(<?>,<?>)";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Whole part'; ru = 'Целая часть числа';pl = 'Cała część';es_ES = 'Parte entera';es_CO = 'Parte entera';tr = 'Tamamı';it = 'Parte intera';de = 'Gesamtteil'");
		NewRow.Operator			= " Int(<?>)";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Round'; ru = 'Округление';pl = 'Zaokrąglenie';es_ES = 'Redondeado';es_CO = 'Redondeado';tr = 'Yuvarlak';it = 'Arrotonda';de = 'Rund'");
		NewRow.Operator			= " Round(<?>,<Precision?>)";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Predefined value'; ru = 'Предопределенное значение';pl = 'Predefiniowana wartość';es_ES = 'Valor predeterminado';es_CO = 'Valor predeterminado';tr = 'Öntanımlı değer';it = 'Valore predefinito';de = 'Vordefinierter Wert'");
		NewRow.Operator			= " PredefinedValue(<?>)";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Value is filled'; ru = 'Значение заполнено';pl = 'Wartość jest wypełniona';es_ES = 'Valor está rellenado';es_CO = 'Valor está rellenado';tr = 'Değer dolduruldu';it = 'Valore compilato';de = 'Wert ist ausgefüllt'");
		NewRow.Operator			= " ValueIsFilled(<?>)";
		
		RowsGroup 				= OperatorsTree.Rows.Add();
		RowsGroup.Description	= NStr("en ='TEMPLATE'; ru = 'МАКЕТ';pl = 'SZABLON';es_ES = 'MODELO';es_CO = 'MODELO';tr = 'Şablon';it = 'MODELLO';de = 'VORLAGE'");
		RowsGroup.Picture		= 1;
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""1%""";
		NewRow.Operator			= " %1";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""5%""";
		NewRow.Operator			= " %5";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""20%""";
		NewRow.Operator			= " %20";
		
		NewRow 					= RowsGroup.Rows.Add();
		NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""50%""";
		NewRow.Operator			= " %50";
		
	EndIf;
	
	ValueToFormAttribute(OperatorsTree, "Operators");
	
EndProcedure

&AtClient
Procedure CheckFormula(Command)
	
	Errors = Undefined;
	
	CheckFormulaServer(Errors);
	
	ClearMessages();
	
	If Errors = Undefined Then
		
		TextAlert = NStr("en ='The formula is correct.'; ru = 'Формула правильная.';pl = 'Formuła jest poprawna.';es_ES = 'La fórmula es correcta.';es_CO = 'La fórmula es correcta.';tr = 'Formül doğru.';it = 'La formula è corretta.';de = 'Die Formel ist richtig.'");
		ShowMessageBox(, TextAlert, , NStr("en ='Formula check'; ru = 'Проверка формулы';pl = 'Sprawdzenie formuły';es_ES = 'Compruebe la fórmula';es_CO = 'Compruebe la fórmula';tr = 'Formül kontrolü';it = 'Controllo formula';de = 'Formelüberprüfung'"));
		
	Else
		
		CommonClientServer.ReportErrorsToUser(Errors);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckFormulaServer(Errors)
	
	MapOperands			= New Structure;
	CalculatedData		= Undefined;
	ValueAllOperands	= 10; // When checking the formula, the values of all operands are assumed to be 10
	
	FormulaText = TrimAll(Formula);
	If Not ValueIsFilled(FormulaText) Then
		
		ErrorText = NStr("en ='The formula is empty.'; ru = 'Формула пустая.';pl = 'Formuła jest pusta.';es_ES = 'La fórmula está vacía.';es_CO = 'La fórmula está vacía.';tr = 'Formül boş.';it = 'La formula è vuota.';de = 'Die Formel ist leer.'");
		CommonClientServer.AddUserError(Errors, , ErrorText, "");

		Return;
	EndIf;
	
	If StrOccurrenceCount(FormulaText, OperandBegin) <> StrOccurrenceCount(FormulaText, OperandEnd) Then
		
		ErrorText = NStr("en ='The number of open operands is not equal to the number of closed.'; ru = 'Количество открытых операндов не соответствует количеству закрытых операндов.';pl = 'Ilość otwartych operandów nie odpowiada ilości zamkniętych.';es_ES = 'El número de operandos abiertos no es igual al número de operandos cerrados.';es_CO = 'El número de operandos abiertos no es igual al número de operandos cerrados.';tr = 'Açık işlenenlerin sayısı kapalı olanların sayısına eşit değil.';it = 'Il numero di operandi aperti non è uguale al numero di quelli chiusi.';de = 'Die Anzahl der offenen Operanden ist nicht gleich der Anzahl der geschlossenen Operanden.'");
		CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		
	EndIf;
	
	If StrOccurrenceCount(FormulaText, "(") <> StrOccurrenceCount(FormulaText, ")") Then
		
		ErrorText = NStr("en ='The number of open brackets is not equal to the number of closed ones.'; ru = 'Количество открытых скобок не соответствует количеству закрытых.';pl = 'Ilość otwartych nawiasów nie odpowiada ilości zamkniętych.';es_ES = 'El número de paréntesis abiertos no es igual al número de paréntesis cerrados.';es_CO = 'El número de paréntesis abiertos no es igual al número de paréntesis cerrados.';tr = 'Açık parantezlerin sayısı kapalı olanların sayısına eşit değil.';it = 'Il numero di parentesi aperte è diverso da quello di quelle chiuse.';de = 'Die Anzahl der offenen Klammern ist nicht gleich der Anzahl der geschlossenen Klammern.'");
		CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		
	EndIf;
	
	If StrOccurrenceCount(FormulaText, "<") <> 0 Or StrOccurrenceCount(FormulaText, ">") <> 0 Then
		
		ErrorText = NStr("en = 'Parameter is required in ""<?>"".'; ru = 'Укажите параметр в ""<?>"".';pl = 'Parametr jest wymagany w ""<?>"".';es_ES = 'El parámetro se requiere en ""<?>"".';es_CO = 'El parámetro se requiere en ""<?>"".';tr = '""<?>""de parametre gerekli.';it = 'Il parametro è richiesto in ""<?>"".';de = 'Parameter ist in ""<?>"" erforderlich.'");
		CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		
	EndIf;
	
	Operands = ParsingFormulaForOperands(FormulaText, Errors);
	
	If IsAmountSelection Then
		InsertOperandsValues(FormulaText, ValueAllOperands);
		PriceGenerationFormulaServerCall.CalculateDataByFormula(FormulaText, MapOperands, CalculatedData);
	ElsIf IsPeriodSelection Then
		InsertOperandsValues(FormulaText, "&Period");
		CalculateDataByPeriodFormula(FormulaText, CalculatedData);
	EndIf;
	
	If CalculatedData.ErrorCalculation Then
		
		ErrorText = NStr("en = 'There were errors in the calculation. Check the spelling of the formula.'; ru = 'При расчете возникли ошибки. Проверьте написание формулы.';pl = 'W obliczeniu były błędy. Sprawdź prawidłowość formuły.';es_ES = 'Hay errores en el cálculo. Revise la ortografía de la fórmula.';es_CO = 'Hay errores en el cálculo. Revise la ortografía de la fórmula.';tr = 'Hesaplamada hatalar oluştu. Formülün yazılışını kontrol edin.';it = 'Sono stati rilevati errori nel calcolo. Controllare che la formula sia scritta correttamente.';de = 'Bei der Berechnung sind Fehler aufgetreten. Überprüfen Sie die Schreibweise der Formel.'");
		
		CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CalculateDataByPeriodFormula(Val FormulaText, CalculatedData = Undefined) 
	
	If CalculatedData = Undefined Then
		CalculatedData = New Structure("Price, MeasurementUnit, ErrorCalculation, ErrorText", 0, Undefined, False);
	EndIf;
		
	Query = New Query;
	Query.Text = StrTemplate("SELECT %1;", FormulaText);
	
	Query.SetParameter("Period", CurrentSessionDate());

	Try
		QueryResult = Query.Execute();
	Except
		CalculatedData.ErrorCalculation	= True;
		CalculatedData.ErrorText		= DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServer
Function ParsingFormulaForOperands(Formula, Errors)
	
	Operands = New Array;
	
	FormulaText = TrimAll(Formula);
	If IsBlankString(FormulaText) Then
		Return Operands;
	EndIf;
		
	OperandsCount = StrOccurrenceCount(FormulaText, OperandBegin);
	
	While OperandsCount > 0 Do
		
		OperandBeginIndex	= Find(FormulaText, OperandBegin);
		OperandEndIndex		= Find(FormulaText, OperandEnd);
		
		Operand				= Mid(FormulaText, OperandBeginIndex, OperandEndIndex - OperandBeginIndex + 1);
		OperandNameToCheck	= Mid(FormulaText, OperandBeginIndex + 1, OperandEndIndex - OperandBeginIndex - 1);
		
		If Operands.Find(Operand) <> Undefined Then
			Continue;
		EndIf;
		
		Operands.Add(Operand);
				
		OperandsCount	= OperandsCount - StrOccurrenceCount(FormulaText, Operand);
		FormulaText		= StrReplace(FormulaText, Operand, "");
		
		OperandCheckFilter = New Structure("Field", OperandNameToCheck);
		OperandRows = ParametersDataTable.FindRows(OperandCheckFilter);
		
		If OperandRows.Count() = 0 Then
			OperandRows = NestedParametersDataTable.FindRows(OperandCheckFilter);
		EndIf;
		
		If OperandRows.Count() = 0 Then
			ErrorTemplate = NStr("en = 'Operand %1 not found in attributes tree'; ru = 'Операнд %1 не найден в дереве реквизитов';pl = 'Nie znaleziono argumentu operacji %1 w drzewie atrybutów';es_ES = 'Se ha encontrado el operando %1 en el árbol de atributos';es_CO = 'Se ha encontrado el operando %1 en el árbol de atributos';tr = '%1 işleneni öznitelikler ağacında bulunamadı';it = 'Operando %1 non trovato nell''alberto degli attributi';de = 'Operand %1 nicht gefunden im Baum von Attributen'");
			ErrorText = StrTemplate(ErrorTemplate, OperandNameToCheck);
			CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		EndIf;
		
	EndDo;
	
	Return Operands;
	
EndFunction

&AtClient
Function FindValueInTree(Tree, Value, DrCr)

	For Each Branch In Tree Do
		
		If Branch.Field = Value And Branch.DrCr = DrCr Then
			Return Branch.GetId();
		Else
			RecursionV = FindValueInTree(Branch.GetItems(), Value, DrCr);
			
			If RecursionV <> Undefined Then
				Return RecursionV;
			EndIf;
		EndIf;
	EndDo;

	Return Undefined;
	
EndFunction 

&AtServer
Procedure InitializeTree()
	
	ParametersTree.GetItems().Clear();
	
	ParametersDataTable.Sort("ListSynonym");
	FilterResult = SetFilter();
	
	OrderedCategoriesArray = New Array;
	OrderedCategoriesArray.Add(NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"));
	OrderedCategoriesArray.Add(NStr("en = 'Settings'; ru = 'Настройки';pl = 'Ustawienia';es_ES = 'Configuraciones';es_CO = 'Configuraciones';tr = 'Ayarlar';it = 'Impostazioni';de = 'Einstellungen'"));
	OrderedCategoriesArray.Add(NStr("en = 'Accounting policy settings'; ru = 'Настройки учетной политики';pl = 'Ustawienia polityki rachunkowości';es_ES = 'Ajustes de la política de contabilidad';es_CO = 'Ajustes de la política de contabilidad';tr = 'Muhasebe politikası ayarları';it = 'Impostazioni politica contabile';de = 'Einstellungen von Bilanzierungsrichtlinien'"));
	
	FilteredParamTable 		 = FilterResult.ParametersFilterTable; 
	FilteredNestedParamTable = FilterResult.NestedParametersFilterTable; 
	
	CategoriesTable = FilteredParamTable.Copy( , "Category, CategorySynonym");
	CategoriesTable.GroupBy("Category, CategorySynonym");
	CategoriesTable.Columns.Add("Used");
	CategoriesTable.FillValues(False, "Used");
	
	For Each OrderedCategory In OrderedCategoriesArray Do
		
		FilterCategory = New Structure("CategorySynonym", OrderedCategory);
		CategoryRows = CategoriesTable.FindRows(FilterCategory);
		
		For Each CategoryRow In CategoryRows Do
			CategoryRow.Used = True;
			AddTreeItems(CategoryRow, FilteredParamTable, FilteredNestedParamTable);
		EndDo;
		
	EndDo;
	
	For Each Category In CategoriesTable Do
		
		If Category.Used Then
			Continue;
		EndIf;
		
		AddTreeItems(Category, FilteredParamTable, FilteredNestedParamTable);
		
	EndDo;

EndProcedure

&AtServer
Procedure AddTreeItems(Category, FilteredParamTable, FilteredNestedParamTable)
	
	FilterCategory	= New Structure("Category", Category.Category);
	CategoryRows	= FilteredParamTable.FindRows(FilterCategory);
	
	If Category.Category <> "" Then
		CategoryTreeBranch = ParametersTree.GetItems().Add();
		CategoryTreeBranch.ListSynonym = Category.CategorySynonym;
	Else
		CategoryTreeBranch = ParametersTree;
	EndIf;
	
	For Each ParameterRow In CategoryRows Do
		
		FilterAttr = New Structure;
		FilterAttr.Insert("ParentField"		, ParameterRow.Field);
		FilterAttr.Insert("ParentDrCr"		, ParameterRow.DrCr);
		FilterAttr.Insert("RestrictedByType", False);
		CurrentNestedAttributes = FilteredNestedParamTable.FindRows(FilterAttr);
		
		If CurrentNestedAttributes.Count() = 0 Then
			CurrentNestedAttributes = NestedParametersDataTable.FindRows(FilterAttr);
		EndIf;
		
		If ParameterRow.RestrictedByType
			And (NestedParametersDataTable.Count() = 0 Or CurrentNestedAttributes.Count() = 0) Then
			Continue;
		EndIf;
		
		ParameterTreeRow = CategoryTreeBranch.GetItems().Add();
		FillPropertyValues(ParameterTreeRow, ParameterRow);
		
		AddNestedAttributes(ParameterTreeRow, CurrentNestedAttributes);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddNestedAttributes(TreeRow, CurrentNestedAttributes)

	If NestedParametersDataTable.Count() = 0 Or CurrentNestedAttributes.Count() = 0 Then
		Return;
	EndIf;
		
	For Each NestedRow In CurrentNestedAttributes Do
		
		ParameterTreeRow = TreeRow.GetItems().Add();
		FillPropertyValues(ParameterTreeRow, NestedRow);
		
	EndDo;
	
EndProcedure

&AtServer
Function SetFilter()

	If Not ValueIsFilled(FilterString) Then
		NestedParametersFilterTable = NestedParametersDataTable.Unload();
		ParametersFilterTable		= ParametersDataTable.Unload();
		
		Result = New Structure;
		Result.Insert("ParametersFilterTable"		, ParametersFilterTable);
		Result.Insert("NestedParametersFilterTable"	, NestedParametersFilterTable);
		
		Return Result;
		
	EndIf;

	FiltredNestedRows = New Array;
	
	For Each Row In NestedParametersDataTable Do
		If StrFind(Upper(Row.ListSynonym), Upper(FilterString)) And Not Row.RestrictedByType Then
			FiltredNestedRows.Add(Row);
		EndIf;
	EndDo;
	
	NestedParametersFilterTable = NestedParametersDataTable.Unload(FiltredNestedRows);
	
	FilteredRows = New Array;
	
	For Each Row In ParametersDataTable Do
		If StrFind(Upper(Row.ListSynonym), Upper(FilterString)) Then
			FilteredRows.Add(Row);
		ElsIf NestedParametersFilterTable.Find(Row.Field, "ParentField") <> Undefined Then
			FilteredRows.Add(Row);
		EndIf;
	EndDo;
	
	ParametersFilterTable = ParametersDataTable.Unload(FilteredRows);
	
	Result = New Structure;
	Result.Insert("ParametersFilterTable"		, ParametersFilterTable);
	Result.Insert("NestedParametersFilterTable"	, NestedParametersFilterTable);
	
	Return Result;

EndFunction

&AtServer
Procedure InsertOperandsValues(FormulaText, Value)
	
	FormulaText = TrimAll(FormulaText);
	If IsBlankString(FormulaText) Then
		Return;
	EndIf;
		
	OperandsCount = StrOccurrenceCount(FormulaText, OperandBegin);
	
	While OperandsCount > 0 Do
		
		OperandBeginIndex	= Find(FormulaText, OperandBegin);
		OperandEndIndex		= Find(FormulaText, OperandEnd);
		
		Operand = Mid(FormulaText, OperandBeginIndex, OperandEndIndex - OperandBeginIndex + 1);
		
		OperandsCount	= OperandsCount - StrOccurrenceCount(FormulaText, Operand);
		FormulaText		= StrReplace(FormulaText, Operand, Value);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)
	RebuildTree(Items.ParametersTree.Name, 2);
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	RebuildTree(Items.ParametersTree.Name, 0);
EndProcedure

&AtClient
Procedure RebuildTree(CurrentTree, ExpandLevel)
	
	If ExpandLevel = 0 Then
		
		For Each TreeBranch In ThisObject[CurrentTree].GetItems() Do
			
			For Each NestedTreeBranch In TreeBranch.GetItems() Do
				Items[CurrentTree].Collapse(NestedTreeBranch.GetId());
			EndDo;
			
			Items[CurrentTree].Collapse(TreeBranch.GetId());
			
		EndDo;
		
	ElsIf ExpandLevel = 1 Then
		
		For Each TreeBranch In ThisObject[CurrentTree].GetItems() Do
			Items[CurrentTree].Expand(TreeBranch.GetId(), False);
		EndDo;
		
	ElsIf ExpandLevel = 2 Then
		
		For Each TreeBranch In ThisObject[CurrentTree].GetItems() Do
			Items[CurrentTree].Expand(TreeBranch.GetId(), True);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion