#Region Variables

&AtClient
Var SelectedInValueList;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	If Parameters.AdditionalParameters.Property("OperationKind") Then
		Relationship = ContactsClassification.CounterpartyRelationshipTypeByOperationKind(Parameters.AdditionalParameters.OperationKind);
		FilterCustomer			= Relationship.Customer;
		FilterSupplier			= Relationship.Supplier;
		FilterOtherRelationship	= Relationship.OtherRelationship;
	EndIf;
	
	If Parameters.Filter.Property("Customer") Then
		FilterCustomer = Parameters.Filter.Customer;
		Parameters.Filter.Delete("Customer");
	EndIf;
	
	If Parameters.Filter.Property("Supplier") Then
		FilterSupplier = Parameters.Filter.Supplier;
		Parameters.Filter.Delete("Supplier");
	EndIf;
	
	If Parameters.Filter.Property("OtherRelationship") Then
		FilterOtherRelationship = Parameters.Filter.OtherRelationship;
		Parameters.Filter.Delete("OtherRelationship");
	EndIf;
	
	SetFilterBusinessRelationship(ThisObject, "Customer",			FilterCustomer);
	SetFilterBusinessRelationship(ThisObject, "Supplier",			FilterSupplier);
	SetFilterBusinessRelationship(ThisObject, "OtherRelationship",	FilterOtherRelationship);
	SetFormTitle(ThisObject);
	
	Currency = Undefined;
	If Parameters.Property("Currency", Currency) Then
		
		GroupFilterByCurrencyOrContract = CommonClientServer.CreateFilterItemGroup(
			List.SettingsComposer.Settings.Filter.Items,
			"ByCurrencyOrContract",
			DataCompositionFilterItemsGroupType.OrGroup);
		
		CommonClientServer.AddCompositionItem(
			GroupFilterByCurrencyOrContract,
			"DoOperationsByContracts",
			DataCompositionComparisonType.Equal,
			True,
			,
			True);
		
		CommonClientServer.AddCompositionItem(
			GroupFilterByCurrencyOrContract,
			"SettlementsCurrency",
			DataCompositionComparisonType.Equal,
			Currency,
			,
			True);
		
	EndIf;
	
	ReadHierarchy();
	
	// Establish the form settings for the case of the opening in choice mode
	Items.List.ChoiceMode		= Parameters.ChoiceMode;
	Items.List.MultipleChoice	= ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		PurposeUseKey = "List";
	EndIf;
	
	Items.FilterHierarchyContextMenuIncludingNested.Check = Common.FormDataSettingsStorageLoad(
		FormName,
		"IncludingNested",
		False);
	
	FormFilterOption = FilterOptionForSetting();
	WorkWithFilters.RestoreFilterSettings(ThisObject, List,,,New Structure("FilterPeriod", "CreationDate"), FormFilterOption, True);
	
	ContactInformationPanel.OnCreateAtServer(ThisObject, "ContactInformation");
	
	UseDocumentEvent = GetFunctionalOption("UseDocumentEvent");
	
	SetConditionalAppearance();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Counterparties, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.BatchObjectModification
	Items.ChangeSelected.Visible = AccessRight("Edit", Metadata.Catalogs.Counterparties);
	// End StandardSubsystems.BatchObjectModification
	
	Items.DataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	ShowBalances = True;
	UpdateListQuery();	
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If FormOwner <> Undefined And TypeOf(FormOwner) = Type("FormTable") And FormOwner.Name = "ValueList" Then
		SelectedInValueList = New Array;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SaveFilterSettings();

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_CounterpartyGroup" Then
		
		ReadHierarchy();
		
	EndIf;
	
	If ContactInformationPanelClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
		RefreshContactInformationPanelServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure FilterCustomerOnChange(Item)
	
	SetFilterBusinessRelationship(ThisObject, "Customer", FilterCustomer);
	SetFormTitle(ThisObject);
	
EndProcedure

&AtClient
Procedure FilterSupplierOnChange(Item)
	
	SetFilterBusinessRelationship(ThisObject, "Supplier", FilterSupplier);
	SetFormTitle(ThisObject);
	
EndProcedure

&AtClient
Procedure FilterOtherRelationshipOnChange(Item)
	
	SetFilterBusinessRelationship(ThisObject, "OtherRelationship", FilterOtherRelationship);
	SetFormTitle(ThisObject);
	
EndProcedure

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, "List", "CreationDate");
	
EndProcedure

&AtClient
Procedure FilterTagChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Tags.Tag", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterSegmentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	SetFilterBySegmentsAtServer(SelectedValue);
	
EndProcedure

&AtClient
Procedure FilterResponsibleChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Responsible", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = Not Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

&AtClient
Procedure ShowHideBalance(Command)
	
	ShowBalances = Not ShowBalances;
	
	Items.ShowHideBalances.Title = ?(ShowBalances, NStr("en = 'Hide balances'; ru = 'Скрыть остатки';pl = 'Ukryj bilansy';es_ES = 'Esconder saldos';es_CO = 'Esconder saldos';tr = 'Bakiyeleri gizle';it = 'Nascondere saldi';de = 'Salden ausblenden'"), NStr("en = 'Show balances'; ru = 'Показывать остатки';pl = 'Pokaż ilość na stanie';es_ES = 'Mostrar saldos';es_CO = 'Mostrar saldos';tr = 'Bakiyeleri göster';it = 'Mostrare saldi';de = 'Salden anzeigen'"));

	UpdateListQuery();	

EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableList

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Item.CurrentRow) <> Type("DynamicListGroupRow") Then
		
		CounterpartyCurrentRow = ?(Item.CurrentData = Undefined, Undefined, Item.CurrentData.Ref);
		If CounterpartyCurrentRow <> CurrentCounterparty Then
		
			CurrentCounterparty = CounterpartyCurrentRow;
			AttachIdleHandler("HandleActivateListRow", 0.2, True);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If FormOwner <> Undefined And TypeOf(FormOwner) = Type("FormTable") And FormOwner.Name = "ValueList" Then
		If TypeOf(Value) = Type("Array") Then
			NewArray = New Array;
			For Each ValueValue In Value Do
				If SelectedInValueList.Find(ValueValue) = Undefined Then
					NewArray.Add(ValueValue);
					SelectedInValueList.Add(ValueValue);
				EndIf;
			EndDo;
			StandardProcessing = False;
			If NewArray.Count() > 0 Then
				NotifyChoice(NewArray);
			EndIf;
		Else
			If SelectedInValueList.Find(Value) = Undefined Then
				SelectedInValueList.Add(Value);
			Else
				StandardProcessing = False;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Not Clone AND Not Folder Then
		
		Cancel = False;
		
		FillingValues = New Structure;
		FillingValues.Insert("Customer",			FilterCustomer);
		FillingValues.Insert("Supplier",			FilterSupplier);
		FillingValues.Insert("OtherRelationship",	FilterOtherRelationship);
		
		FiltersByParent = CommonClientServer.FindFilterItemsAndGroups(List.Filter, "Parent");
		If FiltersByParent.Count() > 0
			AND FiltersByParent[0].Use
			AND ValueIsFilled(FiltersByParent[0].RightValue) Then
			
			FillingValues.Insert("Parent",	FiltersByParent[0].RightValue);
		EndIf;
		
		FormParameters = New Structure;
		FormParameters.Insert("FillingValues", FillingValues);
		
		OpenForm("Catalog.Counterparties.ObjectForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListNewWriteProcessing(NewObject, Source, StandardProcessing)
	
	CurrentItem = Items.List;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableFilterHierarchy

&AtClient
Procedure FilterHierarchyOnActivateRow(Item)
	
	SetFilterByHierarchy(ThisObject);
	
EndProcedure

&AtClient
Procedure FilterHierarchyDragStart(Item, DragParameters, Perform)
	
	If Item.CurrentRow = Undefined Then
		Executing = False;
		Return;
	EndIf;
	
	HierarchyRow = FilterHierarchy.FindByID(Item.CurrentRow);
	If HierarchyRow = Undefined
		Or HierarchyRow.CounterpartyGroup = "All"
		Or HierarchyRow.CounterpartyGroup = "WithoutGroup" Then
		
		Executing = False;
		Return;
	EndIf;
	
	DragParameters.Value = CommonClientServer.ValueInArray(HierarchyRow.CounterpartyGroup);
	
EndProcedure

&AtClient
Procedure FilterHierarchyDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If Row = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	HierarchyRow = FilterHierarchy.FindByID(Row);
	If HierarchyRow = Undefined Or HierarchyRow.CounterpartyGroup = "All" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	DragParameters.AllowedActions	= DragAllowedActions.Move;
	DragParameters.Action			= DragAction.Move;
	
EndProcedure

&AtClient
Procedure FilterHierarchyDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		Or DragParameters.Value.Count() = 0
		Or TypeOf(DragParameters.Value[0]) <> Type("CatalogRef.Counterparties")Then
		
		Return;
	EndIf;
	
	If Row = Undefined Then
		Return;
	EndIf;
	
	HierarchyRow = FilterHierarchy.FindByID(Row);
	If HierarchyRow = Undefined Or HierarchyRow.CounterpartyGroup = "All" Then
		Return;
	EndIf;
	
	NewGroup = ?(HierarchyRow.CounterpartyGroup = "WithoutGroup", PredefinedValue("Catalog.Counterparties.EmptyRef"), HierarchyRow.CounterpartyGroup);
	HierarchyDragServer(DragParameters.Value, NewGroup);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SMS(Command)
	
	If Items.List.CurrentData <> Undefined AND ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("SMS", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure PersonalMeeting(Command)
	
	If Items.List.CurrentData <> Undefined AND ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("PersonalMeeting", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure Other(Command)
	
	If Items.List.CurrentData <> Undefined AND ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("Other", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure PhoneCall(Command)
	
	If Items.List.CurrentData <> Undefined AND ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("PhoneCall", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure Email(Command)
	
	If Items.List.CurrentData <> Undefined AND ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("Email", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure HierarchyChange(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined
		Or TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) <> Type("CatalogRef.Counterparties")
		Or Not ValueIsFilled(Items.FilterHierarchy.CurrentData.CounterpartyGroup) Then
		
		Return;
	EndIf;
	
	ShowValue(Undefined, Items.FilterHierarchy.CurrentData.CounterpartyGroup);
	
EndProcedure

&AtClient
Procedure HierarchyCreateGroup(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillingValues = New Structure;
	If TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) = Type("CatalogRef.Counterparties") Then
		FillingValues.Insert("Parent", Items.FilterHierarchy.CurrentData.CounterpartyGroup);
	EndIf;
	
	OpenForm("Catalog.Counterparties.FolderForm",
		New Structure("FillingValues, IsFolder", FillingValues, True),
		Items.List);
	
EndProcedure

&AtClient
Procedure HierarchyCopy(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined
		Or TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) <> Type("CatalogRef.Counterparties")
		Or Not ValueIsFilled(Items.FilterHierarchy.CurrentData.CounterpartyGroup) Then
		
		Return;
	EndIf;
	
	OpenForm("Catalog.Counterparties.FolderForm",
		New Structure("CopyingValue, IsFolder", Items.FilterHierarchy.CurrentData.CounterpartyGroup, True),
		Items.List);
	
EndProcedure

&AtClient
Procedure HierarchySetDeletionMark(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined
		Or TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) <> Type("CatalogRef.Counterparties")
		Or Not ValueIsFilled(Items.FilterHierarchy.CurrentData.CounterpartyGroup) Then
		
		Return;
	EndIf;
	
	DeletionMark = ChangeGroupDeletionMarkServer(Items.FilterHierarchy.CurrentData.GetID());
	
	NotificationText = StrTemplate(NStr("en = 'Deletion mark %1'; ru = 'Пометка удаления %1';pl = 'Znacznik usunięcia %1';es_ES = 'Marca de borrado %1';es_CO = 'Marca de borrado %1';tr = 'Silme işareti %1';it = 'Contrassegno per l''eliminazione %1';de = 'Löschmarkierung %1'"),
		?(DeletionMark, NStr("en = 'is set'; ru = 'установлена';pl = 'ustawiony';es_ES = 'se ha establecido';es_CO = 'se ha establecido';tr = 'ayarlandı';it = 'è impostato';de = 'ist eingestellt'"), NStr("en = 'is removed'; ru = 'снята';pl = 'zdjęty';es_ES = 'se ha eliminado';es_CO = 'se ha eliminado';tr = 'kaldırıldı';it = 'è stato rimosso';de = 'ist entfernt'")));
		
	ShowUserNotification(
		NotificationText,
		GetURL(Items.FilterHierarchy.CurrentData.CounterpartyGroup),
		Items.FilterHierarchy.CurrentData.CounterpartyGroup,
		PictureLib.Information32);
		
	Items.List.Refresh();;
	
EndProcedure

&AtClient
Procedure HierarchyIncludingNested(Command)
	
	Items.FilterHierarchyContextMenuIncludingNested.Check = Not Items.FilterHierarchyContextMenuIncludingNested.Check;
	SetFilterByHierarchy(ThisObject);
	
EndProcedure

#EndRegion

#Region Hierarchy

&AtServer
Procedure ReadHierarchy()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CASE
		|		WHEN Counterparties.DeletionMark
		|			THEN 1
		|		ELSE 0
		|	END AS IconIndex,
		|	Counterparties.Ref AS CounterpartyGroup,
		|	PRESENTATION(Counterparties.Ref) AS GroupPresentation
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.IsFolder = TRUE
		|
		|ORDER BY
		|	Counterparties.Ref HIERARCHY
		|AUTOORDER";
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	ValueToFormAttribute(Tree, "FilterHierarchy");
	
	CollectionItems = FilterHierarchy.GetItems();
	
	TreeRow = CollectionItems.Insert(0);
	TreeRow.IconIndex			= -1;
	TreeRow.CounterpartyGroup	= "All";
	TreeRow.GroupPresentation	= NStr("en = '<All groups>'; ru = '<Все группы>';pl = '<Wszystkie grupy>';es_ES = '<Todos grupos>';es_CO = '<All groups>';tr = '<Tüm gruplar>';it = '<Tutti i gruppi>';de = '<Alle Gruppen>'");
	
	TreeRow = CollectionItems.Add();
	TreeRow.IconIndex			= -1;
	TreeRow.CounterpartyGroup	= "WithoutGroup";
	TreeRow.GroupPresentation	= NStr("en = '<No group>'; ru = '<Без групп>';pl = '<Brak grupy>';es_ES = '<No hay grupo>';es_CO = '<No group>';tr = '<Grup yok>';it = '<Nessun gruppo>';de = '<Keine Gruppe>'");
	
EndProcedure
	
&AtClientAtServerNoContext
Procedure SetFilterByHierarchy(Form)
	
	Items = Form.Items;
	If Items.FilterHierarchy.CurrentData = Undefined Then
		Return;
	EndIf;
	
	IsFilterByGroup = TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) = Type("CatalogRef.Counterparties");
	
	Items.FilterHierarchyContextMenuHierarchyChange.Enabled				= IsFilterByGroup;
	Items.FilterHierarchyContextMenuHierarchyCopy.Enabled				= IsFilterByGroup;
	Items.FilterHierarchyContextMenuHierarchySetDeletionMark.Enabled	= IsFilterByGroup;
	
	RightValue	= Undefined;
	Compare		= DataCompositionComparisonType.Equal;
	Use			= True;
	
	If IsFilterByGroup Then
		
		If Items.FilterHierarchyContextMenuIncludingNested.Check Then
			Compare = DataCompositionComparisonType.InHierarchy;
		EndIf;
		RightValue = Items.FilterHierarchy.CurrentData.CounterpartyGroup;
		
	ElsIf Items.FilterHierarchy.CurrentData.CounterpartyGroup = "All" Then
		
		Use = False;
		
	ElsIf Items.FilterHierarchy.CurrentData.CounterpartyGroup = "WithoutGroup" Then
		
		RightValue = PredefinedValue("Catalog.Counterparties.EmptyRef");
		
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		Form.List,
		"Parent",
		RightValue,
		Compare,
		,
		Use
	);
	
EndProcedure

&AtServerNoContext
Function ChangeDeletionMark(Counterparty)
	
	CounterpartyObject = Counterparty.GetObject();
	CounterpartyObject.SetDeletionMark(Not CounterpartyObject.DeletionMark, True);
	
	Return CounterpartyObject.DeletionMark;
	
EndFunction

&AtServer
Function  ChangeGroupDeletionMarkServer(CurrentRowID)
	
	CurrentTreeRow = FilterHierarchy.FindByID(CurrentRowID);
	DeletionMark = ChangeDeletionMark(CurrentTreeRow.CounterpartyGroup);
	ChangeIconRecursively(CurrentTreeRow, DeletionMark);
	
	Return DeletionMark;
	
EndFunction

&AtServer
Procedure ChangeIconRecursively(TreeRow, DeletionMark)
	
	TreeRow.IconIndex = ?(DeletionMark, 1, 0);
	
	TreeRows = TreeRow.GetItems();
	For Each ChildRow In TreeRows Do
		ChangeIconRecursively(ChildRow, DeletionMark);
	EndDo;
	
EndProcedure

&AtServer
Procedure HierarchyDragServer(CounterpartiesArray, NewGroup)
	
	SetNewCounterpartiesGroup(CounterpartiesArray, NewGroup);
	
	If CounterpartiesArray[0].IsFolder Then
		
		ReadHierarchy();
		
		RowID = 0;
		CommonClientServer.GetTreeRowIDByFieldValue(
			"CounterpartyGroup",
			RowID,
			FilterHierarchy.GetItems(),
			CounterpartiesArray[0],
			False
		);
		Items.FilterHierarchy.CurrentRow = RowID;
		
	Else
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetNewCounterpartiesGroup(CounterpartiesArray, NewGroup)
	
	For Each Counterparty In CounterpartiesArray Do
		CounterpartyObject = Counterparty.GetObject();
		CounterpartyObject.Parent = NewGroup;
		CounterpartyObject.Write();
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure HandleActivateListRow()
	
	RefreshContactInformationPanelServer();
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterBusinessRelationship(Form, FieldName, Use)
	
	NumberChanged = CommonClientServer.ChangeFilterItems(
		Form.List.SettingsComposer.FixedSettings.Filter,
		FieldName,
		,
		True,
		DataCompositionComparisonType.Equal,
		Use,
		DataCompositionSettingsItemViewMode.Inaccessible);
		
	If NumberChanged = 0 Then
		
		GroupBusinessRelationship = CommonClientServer.FindFilterItemByPresentation(
			Form.List.SettingsComposer.FixedSettings.Filter.Items, "BusinessRelationship");
		
		If GroupBusinessRelationship = Undefined Then
			GroupBusinessRelationship = CommonClientServer.CreateFilterItemGroup(
				Form.List.SettingsComposer.FixedSettings.Filter.Items,
				"BusinessRelationship",
				DataCompositionFilterItemsGroupType.OrGroup);
		EndIf;
		
		CommonClientServer.AddCompositionItem(
			GroupBusinessRelationship,
			FieldName,
			DataCompositionComparisonType.Equal,
			True,
			,
			Use,
			DataCompositionSettingsItemViewMode.Inaccessible);
			
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateListQuery()	
	SetQueryTextList();
	Items.Balance.Visible = ShowBalances;
EndProcedure

&AtServer
Procedure SetQueryTextList()
	
	List.QueryText = 
	"SELECT ALLOWED
	|	Counterparties.Ref AS Ref,
	|	Counterparties.IsFolder AS IsFolder,
	|	Counterparties.Description AS Description,
	|	Counterparties.Code AS Code,
	|	Counterparties.Parent AS Parent,
	|	Counterparties.BasicInformation AS BasicInformation,
	|	CAST(Counterparties.DescriptionFull AS STRING(250)) AS LegalName,
	|	Counterparties.LegalEntityIndividual AS LegalEntityIndividual,
	|	Counterparties.TIN AS TIN,
	|	Counterparties.RegistrationNumber AS RegistrationNumber,
	|	Counterparties.BankAccountByDefault AS BankAccountByDefault,
	|	Counterparties.ContractByDefault AS ContractByDefault,
	|	Counterparties.Responsible AS Responsible,
	|	Counterparties.ContactPerson AS ContactPerson,
	|	Counterparties.AccessGroup AS AccessGroup,
	|	CAST(Counterparties.Comment AS STRING(250)) AS Comment,
	|	Counterparties.CreationDate AS CreationDate,
	|	Counterparties.Customer AS Customer,
	|	Counterparties.Supplier AS Supplier,
	|	Counterparties.OtherRelationship AS OtherRelationship,
	|	Counterparties.CustomerAcquisitionChannel AS CustomerAcquisitionChannel,
	|	CASE
	|		WHEN CounterpartyDuplicates.Counterparty IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ThereAreDuplicates,
	|	CASE
	|		WHEN Counterparties.LegalEntityIndividual = VALUE(Enum.CounterpartyType.Individual)
	|			THEN CASE
	|					WHEN Counterparties.DeletionMark
	|						THEN 3
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN Counterparties.DeletionMark
	|					THEN 2
	|				ELSE 0
	|			END
	|	END AS IconIndex,
	|	Counterparties.Tags.(
	|		LineNumber AS LineNumber,
	|		Tag AS Tag
	|	) AS Tags,
	|	&Balance AS Balance
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|		LEFT JOIN InformationRegister.CounterpartyDuplicates AS CounterpartyDuplicates
	|		ON Counterparties.Ref = CounterpartyDuplicates.Counterparty
	|			AND Counterparties.TIN = CounterpartyDuplicates.TIN
	| ";
	
	If ShowBalances Then
		
		List.QueryText = List.QueryText + "
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance AS AccountsPayableBalance
		|		ON (AccountsPayableBalance.Counterparty = Counterparties.Ref)
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance AS AccountsReceivableBalance
		|		ON (AccountsReceivableBalance.Counterparty = Counterparties.Ref)
		|		LEFT JOIN AccumulationRegister.MiscellaneousPayable.Balance AS MiscellaneousPayableBalance
		|		ON (MiscellaneousPayableBalance.Counterparty = Counterparties.Ref)";
		
		BalanceText = "
		|ISNULL(AccountsReceivableBalance.AmountBalance, 0) 
		| - ISNULL(AccountsPayableBalance.AmountBalance, 0) 
		| + ISNULL(MiscellaneousPayableBalance.AmountBalance, 0)";

	Else
		
		BalanceText = 0;
		
	EndIf;
	
	List.QueryText = StrReplace(List.QueryText, "&Balance" , BalanceText);
	
	List.QueryText = List.QueryText + "
	|WHERE
	|	NOT Counterparties.IsFolder";
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFormTitle(Form)
	
	RelationshipKinds = New Array;
	
	If Form.FilterCustomer Then
		RelationshipKinds.Add(NStr("en = 'Customers'; ru = 'Покупатели';pl = 'Kontrahenci';es_ES = 'Clientes';es_CO = 'Clientes';tr = 'Müşteriler';it = 'Clienti';de = 'Kunden'"));
	EndIf;
	
	If Form.FilterSupplier Then
		RelationshipKinds.Add(NStr("en = 'Suppliers'; ru = 'Поставщики';pl = 'Dostawcy';es_ES = 'Proveedores';es_CO = 'Proveedores';tr = 'Tedarikçiler';it = 'Fornitori';de = 'Lieferanten'"));
	EndIf;
	
	If Form.FilterOtherRelationship Then
		RelationshipKinds.Add(NStr("en = 'Other relationship'; ru = 'Прочие отношения';pl = 'Inna relacja';es_ES = 'Otras relaciones';es_CO = 'Otras relaciones';tr = 'Diğer';it = 'Altre relazioni';de = 'Andere Beziehung'"));
	EndIf;
	
	If RelationshipKinds.Count() > 0 Then
		Title	= "";
		For Each Kind In RelationshipKinds Do
			Title = Title + Kind + ", ";
		EndDo;
		StringFunctionsClientServer.DeleteLastCharInString(Title, 2);
	Else
		Title = NStr("en = 'Counterparties'; ru = 'Контрагенты';pl = 'Kontrahenci';es_ES = 'Contrapartes';es_CO = 'Contrapartes';tr = 'Cari hesaplar';it = 'Controparti';de = 'Geschäftspartner'");
	EndIf;
	
	Form.Title = Title;
	
EndProcedure

&AtServerNoContext
Function SegmentCounterparties(Segment)
	
	SegmentCounterparties = New Array;
	
	SegmentContent = Catalogs.CounterpartySegments.GetSegmentContent(Segment);
	CommonClientServer.SupplementArray(SegmentCounterparties, SegmentContent, True);
	
	Return SegmentCounterparties;

EndFunction

&AtClient
Procedure CreateEventByCounterparty(EventTypeName, Counterparty)
	
	FillingValues = New Structure;
	FillingValues.Insert("EventType", PredefinedValue("Enum.EventTypes." + EventTypeName));
	FillingValues.Insert("Counterparty", Counterparty);
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region ContactInformationPanel

&AtServer
Procedure RefreshContactInformationPanelServer()
	
	ContactInformationPanel.RefreshPanelData(ThisObject, CurrentCounterparty);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ContactInformationPanelClient.ContactInformationPanelDataSelection(ThisObject, Item, SelectedRow, Field, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataOnActivateRow(Item)
	
	ContactInformationPanelClient.ContactInformationPanelDataOnActivateRow(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataExecuteCommand(Command)
	
	ContactInformationPanelClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region FilterLabel

&AtServer
Procedure SetFilterBySegmentsAtServer(SelectedValue)
	
	GroupName = Items.FilterSegment.Parent.Name;
	
	SegmentCounterparties = SegmentCounterparties(SelectedValue);
	SetLabelAndListFilter("Ref", GroupName, SegmentCounterparties, String(SelectedValue));
	SelectedValue = Undefined;
	
EndProcedure

&AtServer
Procedure SetLabelAndListFilter(ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation="")
	
	If ValuePresentation="" Then
		ValuePresentation=String(SelectedValue);
	EndIf; 
	
	WorkWithFilters.AttachFilterLabel(ThisObject, ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, ListFilterFieldName,,True);
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, URLFS, StandardProcessing)
	
	StandardProcessing = False;
	
	LabelID = Mid(Item.Name, StrLen("Label_")+1);
	DeleteFilterLabel(LabelID);
	
EndProcedure

&AtServer
Procedure DeleteFilterLabel(LabelID)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, LabelID);

EndProcedure

&AtServer
Function FilterOptionForSetting()
	
	If FilterCustomer AND Not FilterSupplier Then
		FormFiltersOption = "Customers";
	ElsIf Not FilterCustomer AND FilterSupplier Then
		FormFiltersOption = "Suppliers";
	Else
		FormFiltersOption = "";
	EndIf; 

	Return FormFiltersOption;
	
EndFunction

&AtServer
Procedure SaveFilterSettings()
	
	FormFiltersOption = FilterOptionForSetting();
	WorkWithFilters.SaveFilterSettings(ThisObject,,,FormFiltersOption);
	
	Common.FormDataSettingsStorageSave(
		FormName,
		"IncludingNested",
		Items.FilterHierarchyContextMenuIncludingNested.Check
	);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription",	New Structure("FullMetadataObjectName, Type", "Counterparties", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		ShowMessageBox(,NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure
// End StandardSubsystems.DataImportFromExternalSource

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ColorError	= StyleColors.ErrorCounterpartyHighlightColor;
	
	// List
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ThereAreDuplicates");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorError);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("TIN");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion