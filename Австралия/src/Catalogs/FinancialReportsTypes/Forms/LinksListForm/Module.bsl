#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.DeletionMode Then
		Title = NStr("en = 'Report item deletion'; ru = 'Удаление элемента отчета';pl = 'Usunięcie pozycji raportu';es_ES = 'Borrar el elemento del informe';es_CO = 'Borrar el elemento del informe';tr = 'Rapor ögesi silme';it = 'Eliminazione elemento report';de = 'Löschen von Berichtselementen'");
		Items.CancelButton.Title = NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annullare';de = 'Abbrechen'");
	EndIf;
	
	ActionCopy = 0;
	ActionMove = 1;
	ActionDelete = 2;
	MainAction = ActionCopy;
	
	ReportItem = Parameters.ReportItem;
	ItemDescription = ReportItem.DescriptionForPrinting;
	DeletionMode = Parameters.DeletionMode;
	DeleteAll = Parameters.DeleteAll;
	RefreshRefsTree();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetAvailability();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CopyToAllOnChange(Item)
	
	SetAvailability();
	
EndProcedure

&AtClient
Procedure MoveOnChange(Item)
	
	SetAvailability();
	
EndProcedure

&AtClient
Procedure DeleteAllOnChange(Item)
	
	SetAvailability();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersItemRefsTree

&AtClient
Procedure ItemRefsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure("Key", Item.CurrentData.ReportType);
	FormParameters.Insert("CurrentReportItem", Item.CurrentData.ReportItem);
	OpenForm("Catalog.FinancialReportsTypes.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ItemRefsTreeBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Process(Command)
	
	ShowQueryBox(
		New NotifyDescription("ProcessCommandHandler", ThisObject),
		NStr("en = 'This action is irreversible. Continue?'; ru = 'Это действие необратимо. Продолжить?';pl = 'To działanie jest nieodwracalne. Kontynuować?';es_ES = 'Esta acción es irreversible. ¿Continuar?';es_CO = 'Esta acción es irreversible. ¿Continuar?';tr = 'Bu işlem geri alınamaz. Devam et?';it = 'Questa azione è irreversibile. Continuare?';de = 'Diese Aktion ist irreversibel. Fortsetzen?'"),
		QuestionDialogMode.YesNo,
		,
		DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure ProcessCommandHandler(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SelectedItem = Undefined;
	If MainAction = ActionMove Then
		If Items.ItemRefsTree.CurrentRow = Undefined Then
			ShowMessageBox(Undefined, NStr("en = 'Specify a new links source.'; ru = 'Укажите новый источник ссылок.';pl = 'Wybierz źródło nowych linków.';es_ES = 'Especificar una nueva fuente de enlaces.';es_CO = 'Especificar una nueva fuente de enlaces.';tr = 'Yeni bir bağlantı kaynağı belirt.';it = 'Specificare una nuova fonte del collegamento.';de = 'Geben Sie eine neue Verbindungsquelle an.'"));
			Return;
		EndIf;
		CurrentData = Items.ItemRefsTree.CurrentData;
		SelectedItem = CurrentData.ReportItem;
		If Not ValueIsFilled(SelectedItem) Then
			ChildRows = FinancialReportingClientServer.ChildItems(CurrentData);
			SelectedItem = ChildRows[0].ReportItem;
		EndIf;
	EndIf;
	ProcessAtServer(SelectedItem);
	
	Close(True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetAvailability()
	
	If DeleteAll Then
		MainAction = ActionDelete;
		Items.CopyToAll.Enabled = False;
		Items.Move.Enabled = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessAtServer(SelectedItem = Undefined)
	
	// copying original data to the selected item and breaking the link
	If SelectedItem <> Undefined Then
		NewOriginal = SelectedItem.GetObject();
		FillItemData(NewOriginal);
		NewOriginal.LinkedItem = Undefined;
		NewOriginal.Write();
	EndIf;
	
	ReportsTypes = FinancialReportingClientServer.ChildItems(ItemRefsTree);
	For Each ReportType In ReportsTypes Do
		ReportItems = FinancialReportingClientServer.ChildItems(ReportType);
		For Each ItemRef In ReportItems Do
			
			If SelectedItem <> Undefined And ItemRef.ReportItem = SelectedItem Then
				Continue;
			EndIf;
			
			ItemObject = ItemRef.ReportItem.GetObject();
			If MainAction = ActionDelete Then
				ItemObject.SetDeletionMark(True);
			EndIf;
			ItemObject.LinkedItem = SelectedItem;
			If MainAction = ActionCopy Then
				FillItemData(ItemObject);
			EndIf;
			ItemObject.Write();
			
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillItemData(ObjectReceiver)
	
	FillPropertyValues(ObjectReceiver, ReportItem, , "Code, Owner, Parent, DescriptionForPrinting, Comment");
	
	OutputItemTitle = ObjectReceiver.ItemTypeAttributes.Find(ChartsOfCharacteristicTypes.FinancialReportsItemsAttributes.OutputItemTitle);
	If OutputItemTitle <> Undefined Then
		ObjectReceiver.ItemTypeAttributes.Delete(OutputItemTitle);
	EndIf;
	
	AdditionalAttributes = ReportItem.ItemTypeAttributes.Unload();
	For Each Attribute In AdditionalAttributes Do
		If Attribute.Attribute.PredefinedDataName = "RowCode"
			Or Attribute.Attribute.PredefinedDataName = "Note" Then
			Continue;
		EndIf;
		NewRow = ObjectReceiver.ItemTypeAttributes.Add();
		FillPropertyValues(NewRow, Attribute);
	EndDo;
	ObjectReceiver.FormulaOperands.Load(ReportItem.FormulaOperands.Unload());
	ObjectReceiver.TableItems.Load(ReportItem.TableItems.Unload());
	
EndProcedure

&AtServer
Procedure RefreshRefsTree()
	
	TreeParameters = FinancialReportingClientServer.ItemsTreeNewParameters();
	TreeParameters.TreeItemName = "ItemRefsTree";
	TreeParameters.Insert("ReportItem", Parameters.ReportItem);
	TreeParameters.Insert("Account", Parameters.Account);
	
	FinancialReportingServer.RefreshItemRefsTree(ThisObject, TreeParameters);
	
	RefsCount = TreeParameters.RefsCount;
	TextPattern = NStr("en = 'Item ""%1""
		|has %2 links to other reports.
		|Select an action:'; 
		|ru = 'Элемент ""%1""
		|имеет %2 ссылки(ок) на другие отчеты.
		|Выберите действие:';
		|pl = 'Pozycja ""%1""
		|ma %2 linków do innych raportów.
		|Wybierz działanie:';
		|es_ES = 'El elemento ""%1""
		|tiene%2 enlaces a otros informes.
		|Seleccione una acción:';
		|es_CO = 'El elemento ""%1""
		|tiene%2 enlaces a otros informes.
		|Seleccione una acción:';
		|tr = '""%1"" öğesi
		|başka raporlara %2 bağlantı içeriyor.
		|Bir işlem seçin:';
		|it = 'L''elemento ""%1""
		|ha %2 collegamenti a altri report.
		|Selezionare una azione:';
		|de = 'Element ""%1""
		|hat %2 Links zu anderen Berichten.
		|Wählen Sie eine Aktion aus:'");
	
	Text = StringFunctionsClientServer.SubstituteParametersToString(TextPattern, ItemDescription, RefsCount);
	Items.Explanation.Title = Text;
	
	If RefsCount = 1 Then
		Items.Move.ReadOnly = True;
		MainAction = ActionCopy;
	Else
		Items.Move.ReadOnly = False;
	EndIf;
	
EndProcedure

#EndRegion