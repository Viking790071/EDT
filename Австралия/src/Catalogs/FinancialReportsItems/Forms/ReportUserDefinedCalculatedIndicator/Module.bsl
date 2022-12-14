
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	ObjectData = Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	MainStorageID = Parameters.MainStorageID;
	
	If Parameters.Property("ConfigureCells") Then
		ReportItemsAddress = Parameters.ReportItemsAddress;
		ItemsTableAddress = Parameters.ItemsTableAddress;
	EndIf;
	
	RefreshNewItemsTree();
	
	OperatorsTree = FinancialReportingServerCall.BuildOperatorsTree();
	ValueToFormAttribute(OperatorsTree, "Operators");
	
	FillingData = FinancialReportingClientServer.NewRowFillingData();
	For Each OperandRow In ObjectData.FormulaOperands Do
		NewRow = Operands.Add();
		NewRow.ReportItem = OperandRow.Operand;
		NewRow.ID = OperandRow.ID;
		If TypeOf(OperandRow) = Type("ValueTableRow") Then
			NewRow.ItemStructureAddress = OperandRow.ItemStructureAddress;
		Else
			NewRow.ItemStructureAddress = FinancialReportingServerCall.PutItemToTempStorage(OperandRow.Operand, Parameters.MainStorageID);
		EndIf;
		If ValueIsFilled(NewRow.ItemStructureAddress) Then
			ItemData = GetFromTempStorage(NewRow.ItemStructureAddress);
		Else
			ItemData = NewRow.ReportItem;
		EndIf;
		FillingData.Source = ItemData;
		FillingData.RowRecipient = NewRow;
		FillingData.ItemAddressInTempStorage = NewRow.ItemStructureAddress;
		FinancialReportingClientServer.FillTreeRow(FillingData);
		NewRow.NonstandardPicture = FinancialReportingCached.NonstandardPicture(NewRow.ItemType);
	EndDo;
	
	Items.AdditionalAttributes.Visible = Parameters.ShowRowCodeAndNote;
	RefreshFormTitle();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OperatorsSections = Operators.GetItems();
	If OperatorsSections.Count() > 0 Then
		Items.Operators.Expand(OperatorsSections[0].GetID());
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CheckFormulaAtServer(Cancel);
	If Not Cancel Then
		AdditionalMode = Enums.ReportItemsAdditionalModes.ReportType;
		Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel, AdditionalMode);
		If ValueIsFilled(ItemAddressInTempStorage) Then
			ItemStructure = GetFromTempStorage(ItemAddressInTempStorage);
			ItemStructure.FormulaOperands.Clear();
			For Each OperandRow In Operands Do
				If Not ValueIsFilled(OperandRow.ItemStructureAddress) Then
					ItemAddress = FinancialReportingClientServer.PutItemToTempStorage(OperandRow, MainStorageID);
					OperandRow.ItemStructureAddress = ItemAddress;
				EndIf;
				FillPropertyValues(ItemStructure.FormulaOperands.Add(), OperandRow);
			EndDo;
			PutToTempStorage(ItemStructure, ItemAddressInTempStorage);
		EndIf;
	EndIf;
	Return;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	RefreshFormTitle();
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ValueIsFilled(ItemAddressInTempStorage) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ValueIsFilled(ValueSelected) Then
		RefreshExistingItemsTree();
	EndIf;

	FinancialReportingClient.ExpandExistingItemsTree(ThisObject, ExistingItemsTree);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionForPrintingOnChange(Item)
	
	Object.Description = Object.DescriptionForPrinting;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure NewItemsQuickSearchOnChange(Item)
	
	RefreshNewItemsTree();
	
EndProcedure

&AtClient
Procedure ExistingItemsQuickSearchOnChange(Item)
	
	RefreshExistingItemsTree();
	
EndProcedure

&AtClient
Procedure ReportTypeFilterOnChange(Item)
	
	RefreshExistingItemsTree();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperators

&AtClient
Procedure OperatorsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	InsertOperatorIntoFormula();
	
EndProcedure

&AtClient
Procedure OperatorsDragStart(Item, DragParameters, Perform)
	
	If ValueIsFilled(Item.CurrentData.Operator) Then
		DragParameters.Value = Item.CurrentData.Operator;
	Else
		Perform = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersNewItemsTree

&AtClient
Procedure NewItemsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	SelectedOperands = New Array;
	SelectedOperands.Add(Item.CurrentData);
	FinancialReportingClient.AddFormulaOperands(ThisObject, SelectedOperands, Operands);
	
EndProcedure

&AtClient
Procedure NewItemsTreeDragStart(Item, DragParameters, Perform)
	
	Index = 0;
	While Index < DragParameters.Value.Count() Do
		
		ID = DragParameters.Value[Index];
		Operand = NewItemsTree.FindByID(ID);
		If Operand.IsFolder Then
			DragParameters.Value.Delete(Index);
			Continue;
		EndIf;
		Index = Index + 1;
		
	EndDo;
	
	If DragParameters.Value.Count() = 0 Then
		Perform = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NewItemsTreeDragEnd(Item, DragParameters, StandardProcessing)
	
	NewOperands = FinancialReportingClient.AddFormulaOperands(ThisObject, DragParameters.Value, Operands);
	FinancialReportingClient.AddFormulaText(ThisObject, NewOperands);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExistingItemsTree

&AtClient
Procedure ExistingItemsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	SelectedOperands = New Array;
	SelectedOperands.Add(Item.CurrentData);
	FinancialReportingClient.AddFormulaOperands(ThisObject, SelectedOperands, Operands);
	
EndProcedure

&AtClient
Procedure ExistingItemsTreeDragEnd(Item, DragParameters, StandardProcessing)
	
	FinancialReportingClient.AddFormulaOperands(ThisObject, DragParameters.Value, Operands);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperands

&AtClient
Procedure OperandsSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name <> "IndicatorsID" Then
		EditIndicator();
	EndIf;
	
EndProcedure

&AtClient
Procedure OperandsDragEnd(Item, DragParameters, StandardProcessing)
	
	FinancialReportingClient.AddFormulaText(ThisObject, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure OperandsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	FinancialReportingClient.AddFormulaOperands(ThisObject,DragParameters.Value,Operands);
	// for DragEnd event of the NewItemsTree to not occur
	DragParameters.Value.Clear();
	
EndProcedure

&AtClient
Procedure OperandsIDTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	Text = TrimAll(Text);
	NewID = "[" + Text + "]";
	OldID = "[" + Items.Operands.CurrentData.ID + "]";
	Formula = StrReplace(Formula, OldID, NewID);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FinishEditing(Command)
	
	FinancialReportingClient.FinishEditingReportItem(ThisObject);
	
EndProcedure

&AtClient
Procedure FindNewItem(Command)
	
	RefreshNewItemsTree();
	
EndProcedure

&AtClient
Procedure FindExistingItem(Command)
	
	RefreshExistingItemsTree();
	FinancialReportingClient.ExpandExistingItemsTree(ThisObject, ExistingItemsTree);
	
EndProcedure

&AtClient
Procedure CheckFormula(Command)
	
	ClearMessages();
	Cancel = False;
	CheckFormulaAtServer(Cancel);
	If Not Cancel Then
		ShowMessageBox(Undefined, NStr("en = 'No syntax errors found'; ru = '???????????????????????????? ???????????? ???? ??????????????';pl = 'Nie znaleziono b????d??w sk??adniowych';es_ES = 'No hay errores de sintaxis';es_CO = 'No hay errores de sintaxis';tr = 'S??zdizimi hatas?? bulunmad??';it = 'Nessun errore di sintassi trovato';de = 'Keine Syntaxfehler gefunden'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure EditOperand(Command)
	
	EditIndicator();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OperandsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.OpeningBalance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.TotalsType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TotalsTypes.Balance;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Opening balance'; ru = '?????????????????? ??????????????';pl = 'Saldo pocz??tkowe';es_ES = 'Saldo de apertura';es_CO = 'Saldo de apertura';tr = 'A????l???? bakiyesi';it = 'Saldo iniziale';de = 'Anfangssaldo'"));
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OperandsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.OpeningBalance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.TotalsType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TotalsTypes.BalanceDr;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Opening balance Dr'; ru = '?????????????????? ?????????????? ????';pl = 'Saldo pocz??tkowe Wn';es_ES = 'Saldo de d??bito inicial';es_CO = 'Saldo de d??bito inicial';tr = 'A????l???? bor?? bakiyesi';it = 'Saldo iniziale Deb';de = 'Anfangssaldo Soll'"));
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OperandsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.OpeningBalance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.TotalsType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TotalsTypes.BalanceCr;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Opening balance Cr'; ru = '?????????????????? ?????????????? ????';pl = 'Saldo pocz??tkowe Ma';es_ES = 'Saldo de cr??dito inicial';es_CO = 'Saldo de cr??dito inicial';tr = 'A????l???? alacak bakiyesi';it = 'Saldo iniziale Cred';de = 'Anfangssaldo Haben'"));
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OperandsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.OpeningBalance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.TotalsType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TotalsTypes.Balance;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Closing balance'; ru = '???????????????? ??????????????';pl = 'Saldo ko??cowe';es_ES = 'Saldo final';es_CO = 'Saldo final';tr = 'Kapan???? bakiyesi';it = 'Saldo di chiusura';de = 'Abschlusssaldo'"));
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OperandsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.OpeningBalance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.TotalsType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TotalsTypes.BalanceDr;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Closing balance Dr'; ru = '???????????????? ?????????????? ????';pl = 'Saldo ko??cowe Wn';es_ES = 'Saldo de d??bito final';es_CO = 'Saldo de d??bito final';tr = 'Kapan???? bor?? bakiyesi';it = 'Saldo di chiusura Deb';de = 'Soll-Abschlusssaldo'"));
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OperandsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.OpeningBalance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.TotalsType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TotalsTypes.BalanceCr;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Closing balance Cr'; ru = '???????????????? ?????????????? ????';pl = 'Saldo ko??cowe Ma';es_ES = 'Saldo de cr??dito final';es_CO = 'Saldo de cr??dito final';tr = 'Kapan???? alacak bakiyesi';it = 'Saldo di chiusura Cred';de = 'Abschlusssaldo Haben'"));
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OperandsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Operands.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", ""); 
	
EndProcedure

&AtServer 
Procedure RefreshNewItemsTree()
	
	TreeParameters = FinancialReportingClientServer.ItemsTreeNewParameters();
	TreeParameters.WorkMode = Undefined;
	TreeParameters.QuickSearch = NewItemsQuickSearch;
	FinancialReportingServer.RefreshNewItemsTree(ThisObject, TreeParameters);
	
EndProcedure

&AtServer 
Procedure RefreshExistingItemsTree()
	
	If Not ValueIsFilled(ExistingItemsQuickSearch)
		And Not ValueIsFilled(ReportTypeFilter) Then
		ExistingItems = ExistingItemsTree.GetItems();
		ExistingItems.Clear();
		Return;
	EndIf;
	
	TreeParameters = FinancialReportingClientServer.ItemsTreeNewParameters();
	TreeParameters.ItemsTreeName = "ExistingItemsTree";
	TreeParameters.WorkMode = Enums.NewItemsTreeDisplayModes.ReportTypeSettingIndicatorsOnly;
	TreeParameters.QuickSearch = ExistingItemsQuickSearch;
	TreeParameters.ReportTypeFilter = ReportTypeFilter;
	
	FinancialReportingServer.RefreshExistingItemsTree(ThisObject, TreeParameters);
	
EndProcedure

&AtClient
Procedure EditIndicator()
	
	SelectedRows = DriveClient.CheckGetSelectedRefsInList(Items.Operands);
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentData = Items.Operands.CurrentData;
	If IsBlankString(CurrentData.ItemStructureAddress) Then
		CurrentData.ItemStructureAddress = FinancialReportingClientServer.PutItemToTempStorage(CurrentData, MainStorageID);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("OperandRowID",				CurrentData.GetID());
	FormParameters.Insert("Key", 						CurrentData.ReportItem);
	FormParameters.Insert("ItemType", 					CurrentData.ItemType);
	FormParameters.Insert("ItemAddressInTempStorage",	CurrentData.ItemStructureAddress);
	FormParameters.Insert("MainStorageID",				MainStorageID);
	FormParameters.Insert("ReportItemsAddress",			ReportItemsAddress);
	FormParameters.Insert("ItemsTableAddress",			ItemsTableAddress);
	FormParameters.Insert("EditedItemAddress",			ItemAddressInTempStorage);
	FormParameters.Insert("ShowRowCodeAndNote",			False);
	
	Notification = New NotifyDescription("RefreshOperandRowAfterModification", ThisObject, FormParameters);
	
	OpenForm("Catalog.FinancialReportsItems.ObjectForm",
		FormParameters, ThisObject, , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure RefreshOperandRowAfterModification(Result, AdditionalParameters) Export
	
	FillingData = FinancialReportingClientServer.NewRowFillingData();
	FillingData.Source = Result;
	FillingData.RowRecipient = AdditionalParameters.OperandRowID;
	FillingData.ItemAddressInTempStorage = AdditionalParameters.ItemAddressInTempStorage;
	FillingData.Field = Operands;
	FinancialReportingClientServer.FillTreeRow(FillingData);
	
EndProcedure

&AtClient
Procedure InsertOperatorIntoFormula()
	
	If ValueIsFilled(Items.Operators.CurrentData.Operator) Then
		TextToPaste = Items.Operators.CurrentData.Operator;
		If Items.Operators.CurrentData.Description = "( )" 
			And ValueIsFilled(Items.Formula.SelectedText) Then
			TextToPaste = "(" + Items.Formula.SelectedText + ")";
		EndIf;
		Items.Formula.SelectedText = TextToPaste;
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckFormulaAtServer(Cancel)
	
	FinancialReportingServerCall.CheckFormula(Formula, Operands.Unload(), Cancel, "Formula", "Object.Formula");
	
EndProcedure

&AtServer
Procedure RefreshFormTitle()
	
	If Not ValueIsFilled(Object.DescriptionForPrinting) Then
		Title = NStr("en = 'User-defined calculated indicator (Create)'; ru = '???????????????????????????????? ?????????????????? ?????????????????? (????????????????)';pl = 'Zdefiniowany przez u??ytkownika wska??nik obliczeniowy (Tworzenie)';es_ES = 'Indicador calculado definido por el usuario (Crear)';es_CO = 'Indicador calculado definido por el usuario (Crear)';tr = 'Kullan??c?? tan??ml?? hesaplanm???? g??sterge (Olu??tur)';it = 'Indicatore calcolato personalizzato (Crea)';de = 'Benutzerdefiniertes Berechnungskennzeichen (Erstellen)'");
	Else
		Title = Object.DescriptionForPrinting + " " + NStr("en = '(User-defined calculated indicator)'; ru = '(???????????????????????????????? ?????????????????? ??????????????????)';pl = '(Zdefiniowany przez u??ytkownika wska??nik obliczeniowy)';es_ES = '(Indicador calculado definido por el usuario)';es_CO = '(Indicador calculado definido por el usuario)';tr = '(Kullan??c?? tan??ml?? hesaplanm???? g??sterge)';it = '(Indicatore calcolato definito dall''utente)';de = '(Benutzerdefiniertes Berechnungskennzeichen)'");
	EndIf;
	
EndProcedure

#EndRegion
