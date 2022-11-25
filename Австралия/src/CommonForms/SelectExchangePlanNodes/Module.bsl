////////////////////////////////////////////////////////////////////////////////
// Selection form for fields of Exchange Plan Node type.
//  
////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Processing the standard parameters.
	If Parameters.CloseOnChoice = False Then
		PickMode = True;
		If Parameters.Property("MultipleChoice") AND Parameters.MultipleChoice = True Then
			MultipleChoice = True;
		EndIf;
	EndIf;
	
	// Preparing the list of used exchange plans.
	If TypeOf(Parameters.ExchangePlansForSelection) = Type("Array") Then
		For each Item In Parameters.ExchangePlansForSelection Do
			If TypeOf(Item) = Type("String") Then
				// Searching for the exchange plan by name.
				AddUsedExchangePlan(Metadata.FindByFullName(Item));
				AddUsedExchangePlan(Metadata.FindByFullName("ExchangePlan." + Item));
				//
			ElsIf TypeOf(Item) = Type("Type") Then
				// Searching for the exchange plan by type.
				AddUsedExchangePlan(Metadata.FindByType(Item));
			Else
				// Searching for the exchange plan by node type.
				AddUsedExchangePlan(Metadata.FindByType(TypeOf(Item)));
			EndIf;
		EndDo;
	Else
		// All exchange plans are available for selection.
		For each MetadataObject In Metadata.ExchangePlans Do
			AddUsedExchangePlan(MetadataObject);
		EndDo;
	EndIf;
	
	ExchangePlansNodes.Sort("ExchangePlanPresentation Asc");
	
	If PickMode Then
		Title = NStr("ru = 'Подбор узлов планов обмена'; en = 'Select exchange plan nodes'; pl = 'Wybierz węzły planu wymiany';es_ES = 'SelectExchangePlanNodes';es_CO = 'SelectExchangePlanNodes';tr = 'Değişim plan düğümleri seç';it = 'Selezione dei nodi del piano di scambio';de = 'Austauschplan- Knoten auswählen'");
	EndIf;
	If MultipleChoice Then
		Items.ExchangePlansNodes.SelectionMode = TableSelectionMode.MultiRow;
	EndIf;
	
	CurrentRow = Undefined;
	Parameters.Property("CurrentRow", CurrentRow);
	
	FoundRows = ExchangePlansNodes.FindRows(New Structure("Node", CurrentRow));
	
	If FoundRows.Count() > 0 Then
		Items.ExchangePlansNodes.CurrentRow = FoundRows[0].GetID();
	EndIf;
	
EndProcedure

#EndRegion

#Region ExchangePlanNodesFormTableItemsEventHandlers

&AtClient
Procedure ExchangePlanNodesChoice(Item, RowSelected, Field, StandardProcessing)
	
	If MultipleChoice Then
		SelectionValue = New Array;
		SelectionValue.Add(ExchangePlansNodes.FindByID(RowSelected).Node);
		NotifyChoice(SelectionValue);
	Else
		NotifyChoice(ExchangePlansNodes.FindByID(RowSelected).Node);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	If MultipleChoice Then
		SelectionValue = New Array;
		For Each SelectedRow In Items.ExchangePlansNodes.SelectedRows Do
			SelectionValue.Add(ExchangePlansNodes.FindByID(SelectedRow).Node)
		EndDo;
		NotifyChoice(SelectionValue);
	Else
		CurrentData = Items.ExchangePlansNodes.CurrentData;
		If CurrentData = Undefined Then
			ShowMessageBox(, NStr("ru = 'Узел не выбран.'; en = 'No nodes are selected.'; pl = 'Nie wybrano węzła.';es_ES = 'Nodo no está seleccionado.';es_CO = 'Nodo no está seleccionado.';tr = 'Ünite seçilmedi.';it = 'Nodo non selezionato.';de = 'Knoten ist nicht ausgewählt.'"));
		Else
			NotifyChoice(CurrentData.Node);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddUsedExchangePlan(MetadataObject)
	
	If MetadataObject = Undefined
		OR NOT Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return;
	EndIf;
	
	If Not AccessRight("Read", MetadataObject) Then
		Return;
	EndIf;
	
	ExchangePlan = Common.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef();
	
	// Filling nodes of the used exchange plans.
	If Parameters.SelectAllNodes Then
		NewRow = ExchangePlansNodes.Add();
		NewRow.ExchangePlan              = ExchangePlan;
		NewRow.ExchangePlanPresentation = MetadataObject.Synonym;
		NewRow.Node                    = ExchangePlan;
		NewRow.NodePresentation       = NStr("ru = '<Все информационные базы>'; en = '<All infobases>'; pl = '<Wszystkie bazy informacyjne>';es_ES = '<Todas infobases>';es_CO = '<All infobases>';tr = '<Tüm Infobase''ler>';it = '<Tutti gli infobase>';de = '<Alle Datenbanken>'");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExchangePlanTable.Ref,
	|	ExchangePlanTable.Presentation AS Presentation
	|FROM
	|	&ExchangePlanTable AS ExchangePlanTable
	|WHERE
	|	NOT ExchangePlanTable.ThisNode
	|
	|ORDER BY
	|	Presentation";
	Query.Text = StrReplace(Query.Text, "&ExchangePlanTable", MetadataObject.FullName());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		NewRow = ExchangePlansNodes.Add();
		NewRow.ExchangePlan              = ExchangePlan;
		NewRow.ExchangePlanPresentation = MetadataObject.Synonym;
		NewRow.Node                    = Selection.Ref;
		NewRow.NodePresentation       = Selection.Presentation;
	EndDo;
	
EndProcedure

#EndRegion
