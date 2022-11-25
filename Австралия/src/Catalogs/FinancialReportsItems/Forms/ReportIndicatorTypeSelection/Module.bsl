#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RefreshNewItemsTree();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NewItemsQuickSearchOnChange(Item)
	
	RefreshNewItemsTree();
	For Each Row In NewItemsTree.GetItems() Do
		Items.NewItemsTree.Collapse(Row.GetID());
		Items.NewItemsTree.Expand(Row.GetID(), False);
	EndDo;
	
EndProcedure

&AtClient
Procedure ExistingItemsQuickSearchOnChange(Item)
	
	RefreshExistingItemsTree();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersNewItemsTree

&AtClient
Procedure NewItemsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	ReportItemSelectionProcessing();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExistingItemsTree

&AtClient
Procedure ExistingItemsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	ReportItemSelectionProcessing();
	
EndProcedure

&AtClient
Procedure ReportTypeFilterOnChange(Item)
	
	RefreshExistingItemsTree();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FindNewItem(Command)
	
	RefreshNewItemsTree();
	For Each Row In NewItemsTree.GetItems() Do
		Items.NewItemsTree.Collapse(Row.GetID());
		Items.NewItemsTree.Expand(Row.GetID(), False);
	EndDo;
	
EndProcedure

&AtClient
Procedure FindExistingItem(Command)
	
	RefreshExistingItemsTree();
	
EndProcedure

&AtClient
Procedure Select(Command)
	
	ReportItemSelectionProcessing();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ReportItemSelectionProcessing()
	
	CurrentData = CurrentItem.CurrentData;
	If Not ValueIsFilled(CurrentData.ItemType)
		Or CurrentData.IsFolder Then
		ShowMessageBox(Undefined, NStr("en = 'Item cannot be selected'; ru = 'Невозможно выбрать элемент';pl = 'Nie można wybrać elementu';es_ES = 'No se puede seleccionar el elemento';es_CO = 'No se puede seleccionar el elemento';tr = 'Öğe seçilemiyor';it = 'L''elemento non può essere selezionato';de = 'Element kann nicht ausgewählt werden'"));
		Return;
	EndIf;
	
	Result = New Structure("ReportItem, ItemType, DescriptionForPrinting");
	Result.ItemType = CurrentData.ItemType;
	Result.DescriptionForPrinting = CurrentData.DescriptionForPrinting;
	If CurrentData.Property("IsLinked") Then
		Result.Insert("LinkedItem", CurrentData.LinkedItem);
		Result.Insert("IsLinked", True);
	Else
		Result.Insert("ReportItem", CurrentData.ReportItem);
		Result.Insert("IsLinked", False);
	EndIf;
	Close(Result);
	
EndProcedure

&AtServer 
Procedure RefreshNewItemsTree()
	
	TreeParameters = FinancialReportingClientServer.ItemsTreeNewParameters();
	TreeParameters.WorkMode = Enums.NewItemsTreeDisplayModes.ReportTypeSettingIndicatorsOnly;
	TreeParameters.QuickSearch = NewItemsQuickSearch;
	
	FinancialReportingServer.RefreshNewItemsTree(ThisObject, TreeParameters);
	Return;
	
EndProcedure

&AtClient
Procedure RefreshExistingItemsTree()
	
	RefreshExistingItemsTreeAtServer();
	If ValueIsFilled(ReportTypeFilter) Then
		FinancialReportingClient.ExpandExistingItemsTree(ThisObject, ExistingItemsTree);
	EndIf;
	
EndProcedure

&AtServer 
Procedure RefreshExistingItemsTreeAtServer()
	
	If Not ValueIsFilled(ExistingItemsQuickSearch)
		And Not ValueIsFilled(ReportTypeFilter) Then
		ExistingItems = ExistingItemsTree.GetItems();
		ExistingItems.Clear();
		Return;
	EndIf;

	TreeParameters = FinancialReportingClientServer.ItemsTreeNewParameters();
	TreeParameters.ItemsTreeName = "ExistingItemsTree";
	TreeParameters.WorkMode = Enums.NewItemsTreeDisplayModes.ReportTypeSettingIndicatorsOnly;
	TreeParameters.ReportTypeFilter = ReportTypeFilter;
	TreeParameters.QuickSearch = ExistingItemsQuickSearch;
	
	FinancialReportingServer.RefreshExistingItemsTree(ThisObject, TreeParameters);
	
EndProcedure

#EndRegion
