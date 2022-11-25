#Region Variables

&AtClient
Var OldValueCounterparty;

&AtClient
Var ExecuteClose;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisIsDriveTrade = Constants.DriveTrade.Get();
	
	EndOfPeriod = CurrentSessionDate() + 7 * 86400;
	CanReceiveSubcontractingServices = GetFunctionalOption("CanReceiveSubcontractingServices");
	
	PurchasesAvailable = AccessRight("Edit", Metadata.Documents.PurchaseOrder);
	// begin Drive.FullVersion
	ProductionAvailable = AccessRight("Edit", Metadata.Documents.ProductionOrder)
		And GetFunctionalOption("UseProductionSubsystem");
	// end Drive.FullVersion
	SubcontractingAvailable = (GetFunctionalOption("TransferRawMaterialsForProcessing")
		Or CanReceiveSubcontractingServices) And AccessRight("Edit", Metadata.Documents.SubcontractorOrderIssued);
	
	RestoreSettings();
	
	If PeriodDuration > 0 Then
		EndOfPeriod = CurrentSessionDate() + PeriodDuration * 86400;
	EndIf;
	
	// Conditional appearance
	SetConditionalAppearanceOnCreate();
	
	DemandShowDetails				= 1;
	RecommendationsShowHideDetails	= 1;
	
	AddressInventory = PutToTempStorage(FormAttributeToValue("Inventory"), UUID);
	
	Items.OrdersGoodsDispatching.Visible = Users.RolesAvailable("UseDataProcessorGoodsDispatching");
	
	// begin Drive.FullVersion
	Items.OrdersLinkWIP.Visible = True;
	// end Drive.FullVersion
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GenerateDemandPeriod();
	
	DemandShowHideDetails();
	RecommendationsShowHideDetails();
	
	OldValueCounterparty = Counterparty;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If Orders.Count() > 0 And Not ExecuteClose Then
		
		Cancel = True;
		
		ShowQueryBox(New NotifyDescription("BeforeCloseEnd", ThisObject),
			NStr("en = 'The Orders tab is filled in. Do you want to close the Demand planning tool?'; ru = 'Вкладка ""Заказы"" заполнена. Закрыть ""Расчет потребностей в запасах""?';pl = 'Karta Zamówienia jest wypełniona. Czy chcesz zamknąć narzędzie Planowanie zapotrzebowania?';es_ES = 'La pestaña Por orden está rellena. ¿Quiere cerrar la herramienta Planificación de demanda?';es_CO = 'La pestaña Por orden está rellena. ¿Quiere cerrar la herramienta Planificación de demanda?';tr = 'Siparişler sekmesi dolduruldu. Talep planlama aracı kapatılsın mı?';it = 'La scheda Ordini è compilata. Chiudere lo strumento Calcolo del fabbisogno di scorte?';de = 'Die Registerkarte Aufträge ist aufgefüllt. Möchten Sie Das Bedarfsplanungstool schließen?'"),
			QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		ExecuteClose = True;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SaveSettings();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DemandShowDetailsOnChange(Item)
	DemandShowHideDetails();
EndProcedure

&AtClient
Procedure RecommendationsShowHideDetailsOnChange(Item)
	RecommendationsShowHideDetails();
EndProcedure

&AtClient
Procedure ReplenishmentMethodChoice(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem = Undefined Or SelectedItem = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	SetFilterReplenishmentMethod(SelectedItem);
	ClearTables();
	
EndProcedure

&AtClient
Procedure FilterReplenishmentMethodStartChoice(Item, ChoiceData, StandardProcessing)
		
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ReplenishmentMethod", ReplenishmentMethod);
	
	OpenForm("DataProcessor.DemandPlanning.Form.FormSelectReplenishmentMethods",
		FormParameters,
		ThisObject,,,,
		New NotifyDescription("ReplenishmentMethodChoice", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	If OldValueCounterparty <> Counterparty
		And (Inventory.GetItems().Count() > 0 Or Recommendations.GetItems().Count() > 0) Then
		
		QueryText = NStr("en = 'The Demand and Recommendations tabs will be cleared.
						|Do you want to continue?'; 
						|ru = 'Вкладки ""Потребность"" и ""Рекомендации"" будут очищены.
						|Продолжить?';
						|pl = 'Karty Zapotrzebowanie i Polecenia zostaną wyczyszczone.
						|Czy chcesz kontynuować?';
						|es_ES = 'Las pestañas Demanda y Recomendaciones serán borradas
						|¿Quiere continuar?';
						|es_CO = 'Las pestañas Demanda y Recomendaciones serán borradas
						|¿Quiere continuar?';
						|tr = 'Talep ve Öneriler sekmeleri silinecek.
						|Devam etmek istiyor musunuz?';
						|it = 'Le schede Fabbisogno e Raccomandazioni saranno cancellate. 
						|Continuare?';
						|de = 'Die Registerkarten Bedarf und Empfehlungen werden gelöscht.
						| Möchten Sie fortfahren?'");
		ShowQueryBox(New NotifyDescription("CounterpartyOnChangeEnd", ThisObject), QueryText, QuestionDialogMode.YesNo, 60);
		Return;
		
	EndIf;
	
	OldValueCounterparty = Counterparty;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	ClearTables();
EndProcedure

&AtClient
Procedure PeriodPresentationOnChange(Item)
	ClearTables();
EndProcedure

&AtClient
Procedure PeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", EndOfPeriod);
	Notification = New NotifyDescription("PeriodPresentationStartChoiceEnd", ThisObject);
	OpenForm("CommonForm.Calendar", ParametersStructure,,,,, Notification);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Item.CurrentData <> Undefined Then
		
		If TypeOf(Item.CurrentData.Products) = Type("DocumentRef.SalesOrder") Then
			OpenForm("Document.SalesOrder.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		ElsIf TypeOf(Item.CurrentData.Products) = Type("DocumentRef.WorkOrder") Then
			OpenForm("Document.WorkOrder.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		ElsIf TypeOf(Item.CurrentData.Products) = Type("DocumentRef.PurchaseOrder") Then
			OpenForm("Document.PurchaseOrder.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		// begin Drive.FullVersion
		ElsIf TypeOf(Item.CurrentData.Products) = Type("DocumentRef.ProductionOrder") Then
			OpenForm("Document.ProductionOrder.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		ElsIf TypeOf(Item.CurrentData.Products) = Type("DocumentRef.ManufacturingOperation") Then
			OpenForm("Document.ManufacturingOperation.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		// end Drive.FullVersion
		ElsIf TypeOf(Item.CurrentData.Products) = Type("DocumentRef.SubcontractorOrderIssued") Then
			OpenForm("Document.SubcontractorOrderIssued.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		ElsIf ValueIsFilled(Item.CurrentData.Document) Then
			ShowValue( , Item.CurrentData.Document);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecommendations

&AtClient
Procedure RecommendationsBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData = Undefined
		Or Not Item.CurrentData.EditAllowed
		And Not (Item.CurrentItem <> Undefined And Item.CurrentItem.Name = "RecommendationsSelected") Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecommendationsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure RecommendationsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure RecommendationsSelectedOnChange(Item)
	
	SecuredQuantity = 0;
	Selected = False;
	
	CurrentDataParent = Items.Recommendations.CurrentData.GetParent();
	
	If CurrentDataParent = Undefined Then
		
		ParentCurrentData = Items.Recommendations.CurrentData.GetItems();
		SelectedParent = Items.Recommendations.CurrentData.Selected;
		Default = True;
		For Each TreeRow In ParentCurrentData Do
			
			If SelectedParent Then
				TreeRow.Selected = Default;
			Else
				TreeRow.Selected = False;
			EndIf;
			
			Default = False;
			
			If TreeRow.Selected Then
				Selected = True;
				SecuredQuantity = SecuredQuantity + TreeRow.Quantity;
			EndIf;
			
		EndDo;
		
		Items.Recommendations.CurrentData.Selected = Selected;
		Items.Recommendations.CurrentData.DemandClosed = (SecuredQuantity >= Items.Recommendations.CurrentData.Quantity);
		
	Else
		
		For Each TreeRow In CurrentDataParent.GetItems() Do
		
			If TreeRow.Selected Then
				
				Selected = True;
				SecuredQuantity = SecuredQuantity + TreeRow.Quantity;
				
			EndIf;
			
		EndDo;
		
		CurrentDataParent.Selected = Selected;
		CurrentDataParent.DemandClosed = (SecuredQuantity >= CurrentDataParent.Quantity);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecommendationsQuantityOnChange(Item)
	
	Item.Parent.CurrentData.Selected = True;
	Item.Parent.CurrentData.Amount = Item.Parent.CurrentData.Quantity * Item.Parent.CurrentData.Price;
	
	RecommendationsSelectedOnChange(Item);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOrders

&AtClient
Procedure OrdersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	// begin Drive.FullVersion
	If Field = Items.OrdersLinkWIP Then
		ShowGenerateWIP(Item.RowData(SelectedRow).Order)
	Else
	// end Drive.FullVersion
		ShowValue(Undefined, Item.RowData(SelectedRow).Order);
	// begin Drive.FullVersion
	EndIf;
	// end Drive.FullVersion
		
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure UpdateInventory(Command)
	
	If Not ValueIsFilled(Company) Then
		CommonClientServer.MessageToUser(NStr("en = 'Company is not selected.'; ru = 'Не выбрана организация.';pl = 'Firma nie jest wybrana.';es_ES = 'Empresa no se ha seleccionado.';es_CO = 'Empresa no se ha seleccionado.';tr = 'İş yeri seçilmedi.';it = 'Azienda non selezionata.';de = 'Firma ist nicht ausgewählt.'"), , "Company");
		Return;
	EndIf;
	
	If Not ValueIsFilled(FilterReplenishmentMethod) Then
		CommonClientServer.MessageToUser(NStr("en = 'Replenishment method is not selected.'; ru = 'Не указан способ пополнения.';pl = 'Nie wybrano sposobu uzupełniania.';es_ES = 'No se ha seleccionado el método de reposición del inventario.';es_CO = 'No se ha seleccionado el método de reposición del inventario.';tr = 'Stok yenileme yöntemi seçilmedi.';it = 'Metodo di rifornimento non selezionato.';de = 'Die Auffüllungsmethode ist nicht ausgewählt.'"), , "FilterReplenishmentMethod");
		Return;
	EndIf;
	
	UpdateAtServer();
	
	Recommendations.GetItems().Clear();
	
	Modified = False;
	
	Orders.Clear();
	
	DemandShowHideDetails();
	
EndProcedure

&AtClient
Procedure GenerateOrders(Command)
	
	ClearMessages();
	GenerateOrdersAtServer();
	
EndProcedure

&AtClient
Procedure MarkToDelete(Command)
	
	OrderMap = New Map;
	
	For Each DocItem In Items.Orders.SelectedRows Do
		
		RowData = Items.Orders.RowData(DocItem);
		OrderMap.Insert(DocItem, RowData.Order);
		
	EndDo;
	
	ProcessedOrders = MarkToDeleteDocumentAtServer(OrderMap);
	
	For Each DocKeyAndValue In ProcessedOrders Do
		
		OrderRow = Orders.FindByID(DocKeyAndValue.Key);
		OrderRow.DefaultPicture = DocKeyAndValue.Value;
		
		NotifyChanged(OrderRow.Order);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure PostDocument(Command)
	
	OrderMap = New Map;
	
	For Each DocItem In Items.Orders.SelectedRows Do
		
		RowData = Items.Orders.RowData(DocItem);
		OrderMap.Insert(DocItem, RowData.Order);
		
	EndDo;
	
	ProcessedOrders = PostDocumentAtServer(OrderMap);
	
	For Each DocKeyAndValue In ProcessedOrders Do
		
		OrderRow = Orders.FindByID(DocKeyAndValue.Key);
		OrderRow.DefaultPicture = DocKeyAndValue.Value;
		
		NotifyChanged(OrderRow.Order);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UndoPosting(Command)
	
	OrderMap = New Map;
	
	For Each DocItem In Items.Orders.SelectedRows Do
		
		RowData = Items.Orders.RowData(DocItem);
		OrderMap.Insert(DocItem, RowData.Order);
		
	EndDo;
	
	ProcessedOrders = UndoPostingDocumentAtServer(OrderMap);
	
	For Each DocKeyAndValue In ProcessedOrders Do
		
		OrderRow = Orders.FindByID(DocKeyAndValue.Key);
		OrderRow.DefaultPicture = DocKeyAndValue.Value;
		
		NotifyChanged(OrderRow.Order);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OrdersSettings(Command)
	
	FormParameters = New Structure;
	// begin Drive.FullVersion
	FormParameters.Insert("IncludeInProductionPlanning", IncludeInProductionPlanning);
	// end Drive.FullVersion
	FormParameters.Insert("PostOrders", PostOrders);
	FormParameters.Insert("SetOrderStatusInProgress", SetOrderStatusInProgress);
	FormParameters.Insert("UseGroupProductsBySupplier", UseGroupProductsBySupplier);
	FormParameters.Insert("UseGroupProductsBySubcontractor", UseGroupProductsBySubcontractor);
	FormParameters.Insert("ShowGroupProductsBySubcontractor", IsGroupProductsBySubcontractor());
	
	OpenForm("DataProcessor.DemandPlanning.Form.FormUserSettings",
		FormParameters,
		ThisObject,,,,
		New NotifyDescription("OrdersSettingsEnd", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure UpdateRecommendations(Command)
	
	If Modified Then
		
		MessageText = NStr("en = 'You have edited the details on the Recommendations tab.
							|These details will be overwritten. Do you want to continue?'; 
							|ru = 'Вы поменяли данные на вкладке ""Рекомендации"".
							|Данные будут перезаписаны. Продолжить?';
							|pl = 'Edytowałeś/aś szczegóły w karcie Polecenia.
							| Te szczegóły zostaną nadpisane. Czy chcesz kontynuować?';
							|es_ES = 'Ha editado los detalles en la pestaña Recomendaciones.
							|Estos detalles se sobrescribirán. ¿Quiere continuar?';
							|es_CO = 'Ha editado los detalles en la pestaña Recomendaciones.
							|Estos detalles se sobrescribirán. ¿Quiere continuar?';
							|tr = 'Öneriler sekmesindeki bilgileri düzenlediniz.
							|Bu bilgiler geçersiz kılınacak. Devam etmek istiyor musunuz?';
							|it = 'Sono stati modificati i dettagli nella scheda Raccomandazioni. 
							|Questi dettagli saranno sovrascritti. Continuare?';
							|de = 'Sie haben in der Registerkarte Empfehlungen bearbeitet.
							|Diese Details werden überschrieben. Möchten Sie fortfahren?'");
		ShowQueryBox(New NotifyDescription("UpdateRecommendationsEnd", ThisObject), MessageText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	UpdateRecommendationsAtServer();
	
	RecommendationsShowHideDetails();
	
EndProcedure

&AtClient
Procedure InventoryOpenProducts(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TabularSectionRow <> Undefined Then
		
		While True Do
			
			If TypeOf(TabularSectionRow.Products) = Type("CatalogRef.Products") Then
				OpenForm("Catalog.Products.Form.ItemForm", New Structure("Key", TabularSectionRow.Products));
				Break;
			Else
				TabularSectionRow = TabularSectionRow.GetParent();
				If TabularSectionRow = Undefined Then
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecommendationsOpenProducts(Command)
	
	TabularSectionRow = Items.Recommendations.CurrentData;
	If TabularSectionRow <> Undefined Then
		
		While True Do
			
			If TypeOf(TabularSectionRow.Products) = Type("CatalogRef.Products") Then
				OpenForm("Catalog.Products.Form.ItemForm", New Structure("Key", TabularSectionRow.Products));
				Break;
			Else
				TabularSectionRow = TabularSectionRow.GetParent();
				If TabularSectionRow = Undefined Then
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShortenPeriod(Command)
	
	EndOfPeriod = EndOfDay(EndOfPeriod - 86400);
	If BegOfDay(CommonClient.SessionDate()) > BegOfDay(EndOfPeriod) Then
		EndOfPeriod = EndOfDay(CommonClient.SessionDate());
	EndIf;
	
	GenerateDemandPeriod();
	
EndProcedure

&AtClient
Procedure ExtendPeriod(Command)
	
	EndOfPeriod = EndOfDay(EndOfPeriod + 86400);
	GenerateDemandPeriod();
	
EndProcedure

&AtClient
Procedure RefreshOrders(Command)
	
	UpdateStateOrdersAtServer();
	
EndProcedure

&AtClient
Procedure GoodsDispatching(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("EndOfPeriod", EndOfPeriod);
	FormParameters.Insert("Company", Company);
	
	OpenForm("DataProcessor.GoodsDispatching.Form", FormParameters);
	
EndProcedure

&AtClient
Procedure RecommendationsClearOrderSelection(Command)
	
	UncheckRecommendations();
	
EndProcedure

&AtClient
Procedure RecommendationsSelectDefaultOrders(Command)
	
	CheckRecommendations();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure DemandShowHideDetails()
	
	For Each ItemInventory In Inventory.GetItems() Do
		
		ItemInventoryID = ItemInventory.GetID();
		
		If DemandShowDetails = 0 Then
			Items.Inventory.Expand(ItemInventoryID, True);
		Else
			Items.Inventory.Collapse(ItemInventoryID);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RecommendationsShowHideDetails()
	
	For Each ItemRecommendations In Recommendations.GetItems() Do
		
		ItemRecommendationsID = ItemRecommendations.GetID();
		
		If RecommendationsShowHideDetails = 0 Then
			Items.Recommendations.Expand(ItemRecommendationsID);
		Else
			Items.Recommendations.Collapse(ItemRecommendationsID);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure PeriodPresentationStartChoiceEnd(CalendarDateEnd, Parameters) Export
	
	If ValueIsFilled(CalendarDateEnd) Then
		
		EndOfPeriod = EndOfDay(CalendarDateEnd);
		If BegOfDay(CommonClient.SessionDate()) > BegOfDay(EndOfPeriod) Then
			EndOfPeriod = EndOfDay(CommonClient.SessionDate());
		EndIf;
		
		GenerateDemandPeriod();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ClearTables();
		OldValueCounterparty = Counterparty;
	Else
		Counterparty = OldValueCounterparty;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateRecommendationsEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		UpdateRecommendationsAtServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateChoiceListReplenishmentMethod()
	
	ReplenishmentMethod.Clear();
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Items.Company.ReadOnly = True;
		Company = Constants.ParentCompany.Get();
	ElsIf Not ValueIsFilled(Company) Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Company = SettingValue;
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
	If PurchasesAvailable Then
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Purchase);
	EndIf;
	
	// begin Drive.FullVersion
	If ProductionAvailable Then
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Production);
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Assembly);
	EndIf;
	// end Drive.FullVersion
	
	If SubcontractingAvailable Then
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Processing);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceOnCreate()
	
	ColorRecommendations = StyleColors.SuccessResultColor;
	
	// Recommendations
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Recommendations.ReceiptDateExpired");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Recommendations.ReceiptDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Filled;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRecommendations);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Recommendations");
	FieldAppearance.Use = True;
	
	// Recommendations
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Recommendations.ReceiptDateExpired");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Recommendations.ReceiptDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Filled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Recommendations.Selected");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", StyleFonts.FontDialogAndMenu);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Recommendations");
	FieldAppearance.Use = True;
	
EndProcedure

&AtServer
Procedure UpdateAtServer()
	
	Query = New Query;
	Query.Text = TradeVersionQueryText();
	// begin Drive.FullVersion
	Query.Text = FullVersionQueryText();
	// end Drive.FullVersion
	
	StartDate = CurrentSessionDate();
	EndDate = ?(EndOfPeriod < StartDate, StartDate, EndOfPeriod);
	StartDate = BegOfDay(StartDate);
	EndDate = EndOfDay(EndDate);
	
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	Query.SetParameter("DateBalance", CurrentSessionDate());
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	
	Query.SetParameter("ReplenishmentMethods", SelectedValueList(ReplenishmentMethod));
	Query.SetParameter("CanReceiveSubcontractingServices", CanReceiveSubcontractingServices);
	
	UpdateColumns(StartDate, EndDate);
	UpdateData(Query.Execute(), StartDate, EndDate);
	
	AddressInventory = PutToTempStorage(FormAttributeToValue("Inventory"), UUID);
	CurrentEndOfPeriod = EndDate;
	
EndProcedure

&AtServer
Procedure UpdateColumns(StartDate, EndDate)
	
	// Deleting previously added items.
	For Each AddedItem In AddedElements Do
		
		Items.Delete(Items[AddedItem.Value]);
		
	EndDo;
	
	ArrayAddedAttributes = New Array;
	
	// Attributes "Period".
	CurrentPeriod = StartDate;
	
	While BegOfDay(CurrentPeriod) <= BegOfDay(EndDate) Do
		
		NewAttribute = New FormAttribute("Period" + Format(CurrentPeriod, "DF=yyyyMMdd"),
			New TypeDescription("Number", New NumberQualifiers(15, 3)),
			"Inventory",
			Format(CurrentPeriod, "DLF=D"));
		ArrayAddedAttributes.Add(NewAttribute);
		
		CurrentPeriod = CurrentPeriod + 86400;
		
	EndDo;
	
	// Deleting previously added attributes and adding new attributes.
	ChangeAttributes(ArrayAddedAttributes, AddedAttributes.UnloadValues());
	
	// Updating added attributes.
	AddedAttributes.Clear();
	
	For Each AddingAttribute In ArrayAddedAttributes Do
		
		AddedAttributes.Add(AddingAttribute.Path + "." + AddingAttribute.Name);
		
	EndDo;
	
	// Adding new items.
	AddedElements.Clear();
	
	For Each Attribute In ArrayAddedAttributes Do
		
		If IsBlankString(Attribute.Title) Then
			
			Continue;
			
		EndIf;
		
		Item = Items.Add(Attribute.Path + Attribute.Name, Type("FormField"), Items[Attribute.Path]);
		Item.Type = FormFieldType.InputField;
		Item.DataPath = Attribute.Path + "." + Attribute.Name;
		Item.Title = Attribute.Title;
		Item.ReadOnly = True;
		Item.Width = 10;
		
		AddedElements.Add(Attribute.Path + Attribute.Name);
		
	EndDo;
	
	// Setting the conditional appearance.
	SetConditionalAppearance(StartDate, EndDate);
	
EndProcedure

&AtServer
Procedure UpdateData(QueryResult, StartDate, EndDate)
	
	// Generate a summary table of the demand diagram.
	TableQueryResult = QueryResult.Unload();
	CalculateInventoryFlowCalendar(TableQueryResult);
	
	// Order - decryption.
	TableLineNeeds = TableQueryResult.CopyColumns();
	AddDrillDownByOrder(TableQueryResult, TableLineNeeds);
	
	// Clearing the result before update.
	ProductsItems = Inventory.GetItems();
	ProductsItems.Clear();
	
	// Previous values of selection fields.
	PreviousRecord = New Structure("Products, Characteristic");
	
	// Tree item containing current products.
	ProductsCurrent = Undefined;
	
	// Decryption.
	StructureDetails = Undefined;
	
	// The structure containing the data of current products and variant.
	StructureDetailing = Undefined;
	
	// Previous column for which the indicators were calculated.
	PreviousColumn = Undefined;
	
	// Selection bypass.
	RecNo = 0;
	RecCountInSample = TableLineNeeds.Count();
	For Each Selection In TableLineNeeds Do
		
		RecNo = RecNo + 1;
		
		// First record in the selection or products and the variant have changed.
		If RecNo = 1
			Or Selection.Products <> PreviousRecord.Products
			Or Selection.Characteristic <> PreviousRecord.Characteristic Then
			
			// Adding previous products.
			AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			// Deleting current products if they do not contain data.
			If ProductsCurrent <> Undefined And ProductsCurrent.GetItems().Count() = 0 Then
				
				ProductsItems.Delete(ProductsCurrent);
				
			EndIf;
			
			// Adding Products.
			ProductsCurrent = ProductsItems.Add();
			ProductsCurrent.Products = Selection.Products;
			
			// Adding previous products.
			AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			ArrayOrders = New Array;
			StructureDetails = New Structure("Details", ArrayOrders);
			
			// Adding products and variants.
			StructureDetailing = New Structure;
			StructureDetailing.Insert("Products", Selection.Products);
			StructureDetailing.Insert("Characteristic", Selection.Characteristic);
			StructureDetailing.Insert("MinInventory", Selection.MinInventory);
			StructureDetailing.Insert("MaxInventory", Selection.MaxInventory);
			StructureDetailing.Insert("Deficit", GetDefaultStructure());
			StructureDetailing.Insert("Overdue", GetDefaultStructure());
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing.Overdue;
			
		EndIf;
		
		StructureDetails.Details.Add(Selection.OrderDetails);
		
		// Record with a period equal to the period start contains overdue items.
		If Selection.Period = StartDate Then
			
			// Setting the values of overdue indicators.
			OverdueDetailing = StructureDetailing.Overdue.Detailing;
			
			OverdueDetailing.OpeningBalance = Selection.AvailableBalance;
			OverdueDetailing.Receipt = Selection.ReceiptOverdue;
			OverdueDetailing.Demand = Selection.NeedOverdue;
			OverdueDetailing.MinInventory = Selection.MinInventory;
			OverdueDetailing.MaxInventory = ?(Selection.MaxInventory = 0, Selection.MinInventory, Selection.MaxInventory);
			
			OverdueDetailing.ClosingBalance = OverdueDetailing.OpeningBalance
				+ OverdueDetailing.Receipt
				- OverdueDetailing.Demand;
			
			// Calculation of overdue deficit.
			If OverdueDetailing.MinInventory >= OverdueDetailing.ClosingBalance Then
				
				StructureDetailing.Overdue.IndicatorValue = OverdueDetailing.MaxInventory - OverdueDetailing.ClosingBalance;
				StructureDetailing.Overdue.Overdue = True;
				
			EndIf;
			
			StructureDetailing.Overdue.Detailing = OverdueDetailing;
			
			DeficitDetailing = StructureDetailing.Deficit.Detailing;
			
			// Setting the values of deficit indicators.
			FillPropertyValues(DeficitDetailing, OverdueDetailing);
			
			// Calculation of the general deficit.
			If DeficitDetailing.MinInventory >= DeficitDetailing.ClosingBalance Then
				
				StructureDetailing.Deficit.IndicatorValue = DeficitDetailing.MaxInventory - DeficitDetailing.ClosingBalance;
				
			EndIf;
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing.Overdue;
			
		EndIf;
		
		// Record of a scheduled period.
		If Selection.Period >= StartDate Then
			
			ColumnName = "Period" + Format(Selection.Period, "DF=yyyyMMdd");
			
			StructureDetailing.Insert(ColumnName, GetDefaultStructure());
			
			ColumnDetailing = StructureDetailing[ColumnName].Detailing;
			
			// Setting the values of indicators in the target period.
			ColumnDetailing.OpeningBalance = PreviousColumn.Detailing.ClosingBalance;
			ColumnDetailing.Receipt = Selection.Receipt;
			ColumnDetailing.Demand = Selection.Demand;
			ColumnDetailing.MinInventory = PreviousColumn.Detailing.MinInventory;
			
			ColumnDetailing.MaxInventory = ?(PreviousColumn.Detailing.MaxInventory = 0,
				PreviousColumn.Detailing.MinInventory,
				PreviousColumn.Detailing.MaxInventory);
			
			ColumnDetailing.ClosingBalance = ColumnDetailing.OpeningBalance
				+ ColumnDetailing.Receipt
				- ColumnDetailing.Demand;
			
			// Setting the values of deficit indicators.
			DeficitDetailing = StructureDetailing.Deficit.Detailing;
			
			DeficitDetailing.Receipt = DeficitDetailing.Receipt + ColumnDetailing.Receipt;
			DeficitDetailing.Demand = DeficitDetailing.Demand + ColumnDetailing.Demand;
			DeficitDetailing.ClosingBalance = DeficitDetailing.OpeningBalance
				+ DeficitDetailing.Receipt
				- DeficitDetailing.Demand;
			
			// Calculation of the deficit for the period.
			If ColumnDetailing.MinInventory >= ColumnDetailing.ClosingBalance Then
			
				StructureDetailing[ColumnName].IndicatorValue = ColumnDetailing.MaxInventory - ColumnDetailing.ClosingBalance;
				StructureDetailing[ColumnName].Overdue = Selection.Overdue;
				
			Else
				
				StructureDetailing[ColumnName].IndicatorValue = 0;
				StructureDetailing[ColumnName].Overdue = Selection.Overdue;
				
			EndIf;
			
			StructureDetailing[ColumnName].Detailing = ColumnDetailing;
			
			// Calculation of the general deficit.
			If DeficitDetailing.MinInventory >= DeficitDetailing.ClosingBalance Then
				
				StructureDetailing.Deficit.IndicatorValue = DeficitDetailing.MaxInventory - DeficitDetailing.ClosingBalance;
				
			Else
				
				StructureDetailing.Deficit.IndicatorValue = 0;
				
			EndIf;
			
			StructureDetailing.Deficit.Detailing = DeficitDetailing;
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing[ColumnName];
			
		EndIf;
		
		// Saving current values of selection fields.
		FillPropertyValues(PreviousRecord, Selection);
		
		// Last record in the selection.
		If RecNo = RecCountInSample Then
			
			// Adding current products.
			AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			// Deleting current products if they do not contain data.
			If ProductsCurrent <> Undefined And ProductsCurrent.GetItems().Count() = 0 Then
				
				ProductsItems.Delete(ProductsCurrent);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function GetDefaultStructure()
	
	Detailing = New Structure;
	Detailing.Insert("OpeningBalance", 0);
	Detailing.Insert("Receipt", 0);
	Detailing.Insert("Demand", 0);
	Detailing.Insert("MinInventory", 0);
	Detailing.Insert("MaxInventory", 0);
	Detailing.Insert("ClosingBalance", 0);
	
	Return New Structure("IndicatorValue, Overdue, Detailing", 0, False, Detailing);
	
EndFunction

&AtServer
Procedure AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate)
	
	If StructureDetailing = Undefined Then
		Return;
	EndIf;
	
	If OnlyDeficit And StructureDetailing.Deficit.IndicatorValue > 0
		Or Not OnlyDeficit And IndicatorsFilled(StructureDetailing) Then
		
		ProductsItems = ProductsCurrent.GetItems();
		
		// Adding the indicator values.
		OpeningBalance = ProductsItems.Add();
		OpeningBalance.Products = NStr("en = 'Opening balance'; ru = 'Начальный остаток';pl = 'Saldo początkowe';es_ES = 'Saldo de apertura';es_CO = 'Saldo de apertura';tr = 'Açılış bakiyesi';it = 'Saldo di apertura';de = 'Anfangssaldo'");
		
		Receipt = ProductsItems.Add();
		Receipt.Products = NStr("en = 'Inbound quantity'; ru = 'Входящее количество';pl = 'Ilość przychodząca';es_ES = 'Cantidad entrante';es_CO = 'Cantidad entrante';tr = 'Gelen miktar';it = 'Quantità in entrata';de = 'Eingehende Menge'");
		
		Demand = ProductsItems.Add();
		Demand.Products = NStr("en = 'Outbound quantity'; ru = 'Исходящее количество';pl = 'Ilość wychodząca';es_ES = 'Cantidad saliente';es_CO = 'Cantidad saliente';tr = 'Giden miktar';it = 'Quantità in uscita';de = 'Ausgehende Menge'");
		Demand.IsDispatchHeader = True;
		
		ClosingBalance = ProductsItems.Add();
		ClosingBalance.Products = NStr("en = 'Closing balance'; ru = 'Конечный остаток';pl = 'Saldo końcowe';es_ES = 'Saldo final';es_CO = 'Saldo final';tr = 'Kapanış bakiyesi';it = 'Saldo di chiusura';de = 'Abschlusssaldo'");
		
		If StructureDetailing.MinInventory = 0 And StructureDetailing.MaxInventory = 0 Then
			
			RegulatoryInventory = Undefined;
			MaxInventory = Undefined;
			
		Else
			
			MinInventory = ProductsItems.Add();
			MinInventory.Products = NStr("en = 'Reorder point'; ru = 'Минимальный запас';pl = 'Stan minimalny';es_ES = 'Punto de un nuevo pedido';es_CO = 'Punto de un nuevo pedido';tr = 'Yeni sipariş noktası';it = 'Punto di riordino';de = 'Nachbestellpunkt'");
			
			MaxInventory = ProductsItems.Add();
			MaxInventory.Products = NStr("en = 'Max level'; ru = 'Максимальный запас';pl = 'Maksymalny poziom';es_ES = 'Nivel máximo';es_CO = 'Nivel máximo';tr = 'Maksimum seviye';it = 'Livello massimo';de = 'Maximales Level'");
			
		EndIf;
		
		ItemsReceipt = Receipt.GetItems();
		ItemsNeedFor = Demand.GetItems();
		
		OrdersArrayReceipt = New Array();
		OrdersArrayNeed = New Array();
		For Each RowDetails In StructureDetails.Details Do
			For Each RowOrder In RowDetails Do
				
				If (RowOrder.Value.Receipt <> 0 
					Or RowOrder.Value.ReceiptOverdue <> 0)
					And OrdersArrayReceipt.Find(RowOrder.Key) = Undefined Then
					
					OrderDetails = ItemsReceipt.Add();
					OrderDetails.Products = RowOrder.Key;
					OrdersArrayReceipt.Add(RowOrder.Key);
					
				EndIf;
				
				ItemsReceiptOverdue = Receipt.GetItems();
				For Each RowReceiptOutdated In ItemsReceiptOverdue Do
					
					If RowReceiptOutdated.Products = RowOrder.Key Then
						
						If RowOrder.Value.ReceiptOverdue <> 0 Then
							
							RowReceiptOutdated.Overdue = RowReceiptOutdated.Overdue + RowOrder.Value.ReceiptOverdue;
							
						EndIf;
						
						If RowOrder.Value.Receipt <> 0 Then
							
							RowReceiptOutdated[RowOrder.Value.Period] = RowReceiptOutdated[RowOrder.Value.Period]
								+ RowOrder.Value.Receipt;
							
						EndIf;
					
						If StructureDetailing.Deficit.IndicatorValue <> 0 Then
							
							RowReceiptOutdated.Deficit = RowReceiptOutdated.Deficit
								+ RowOrder.Value.ReceiptOverdue
								+ RowOrder.Value.Receipt;
							
						EndIf;
						
					EndIf;
					
				EndDo;
				
				If (RowOrder.Value.Demand <> 0
					Or RowOrder.Value.NeedOverdue <> 0)
					And OrdersArrayNeed.Find(RowOrder.Key) = Undefined Then
					
					OrderDetails = ItemsNeedFor.Add();
					OrderDetails.Products = RowOrder.Key;
					OrdersArrayNeed.Add(RowOrder.Key);
					
				EndIf;
				
				ItemsNeedForOverdue = Demand.GetItems();
				For Each StringNeedOverdue In ItemsNeedForOverdue Do
					
					If StringNeedOverdue.Products = RowOrder.Key Then
						
						If RowOrder.Value.NeedOverdue <> 0 Then
						
							StringNeedOverdue.Overdue = StringNeedOverdue.Overdue + RowOrder.Value.NeedOverdue;
						
						EndIf;
						
						If RowOrder.Value.Demand <> 0 Then
						
							StringNeedOverdue[RowOrder.Value.Period] = StringNeedOverdue[RowOrder.Value.Period] + RowOrder.Value.Demand;
						
						EndIf;
						
						If StructureDetailing.Deficit.IndicatorValue <> 0 Then
							
							StringNeedOverdue.Deficit = StringNeedOverdue.Deficit + RowOrder.Value.NeedOverdue + RowOrder.Value.Demand;
							
						EndIf;
						
						If ValueIsFilled(RowOrder.Value.SalesOrder) Then
							
							StringNeedOverdue.SalesOrder = RowOrder.Value.SalesOrder;
							
							If StringNeedOverdue.SalesOrder <> RowOrder.Value.Document Then
								
								StringNeedOverdue.Document = RowOrder.Value.Document;
								
								DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(StringNeedOverdue.Document, True, True);
								SalesOrderNumber = ObjectPrefixationClientServer.GetNumberForPrinting(StringNeedOverdue.SalesOrder, True, True);
								
								StringNeedOverdue.Products = StringFunctionsClientServer.SubstituteParametersToString(
									NStr("en = '%1 %2 (%3 %4)'; ru = '%1 %2 (%3 %4)';pl = '%1 %2 (%3 %4)';es_ES = '%1 %2 (%3 %4)';es_CO = '%1 %2 (%3 %4)';tr = '%1 %2 (%3 %4)';it = '%1 %2 (%3 %4)';de = '%1 %2 (%3 %4)'"),
									StringNeedOverdue.Document.Metadata().Synonym,
									DocumentNumber,
									StringNeedOverdue.SalesOrder.Metadata().Synonym,
									SalesOrderNumber);
								
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndDo;
				
			EndDo;
		EndDo;
		
		For Each Column In StructureDetailing Do
			
			If TypeOf(Column.Value) = Type("Structure") Then
				
				If Column.Key = "Overdue" Then
					
					IsMoreThenZero = (Column.Value.IndicatorValue > 0
						Or Column.Value.Detailing.Receipt > 0
						Or Column.Value.Detailing.Demand > 0);
					
					OpeningBalance[Column.Key] = ?(IsMoreThenZero, Column.Value.Detailing.OpeningBalance, 0);
					
					Receipt[Column.Key] = Column.Value.Detailing.Receipt;
					Demand[Column.Key] = Column.Value.Detailing.Demand;
					
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MinInventory, 0);
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MaxInventory, 0);
						
					EndIf;
					
					ClosingBalance[Column.Key] = ?(IsMoreThenZero, Column.Value.Detailing.ClosingBalance, 0);
					
				ElsIf Column.Key = "Deficit" Then
					
					OpeningBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.OpeningBalance, 0);
					Receipt[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.Receipt, 0);
					Demand[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.Demand, 0);
					
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MinInventory, 0);
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MaxInventory, 0);
						
					EndIf;
					
					ClosingBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.ClosingBalance, 0);
					
				Else
					
					OpeningBalance[Column.Key] = Column.Value.Detailing.OpeningBalance;
					Receipt[Column.Key] = Column.Value.Detailing.Receipt;
					Demand[Column.Key] = Column.Value.Detailing.Demand;
					
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = Column.Value.Detailing.MinInventory;
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = Column.Value.Detailing.MaxInventory;
						
					EndIf;
					
					ClosingBalance[Column.Key] = Column.Value.Detailing.ClosingBalance;
					
				EndIf;
				
				ProductsCurrent[Column.Key] = Column.Value.IndicatorValue;
				
			Else
				
				ProductsCurrent[Column.Key] = Column.Value;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	StructureDetailing = Undefined;
	
EndProcedure

&AtServer
Function IndicatorsFilled(NewProductsCharacteristic)
	
	IndicatorsFilled = False;
	
	For Each Column In NewProductsCharacteristic Do
		
		If TypeOf(Column.Value) = Type("Structure") Then
			
			If Column.Value.Detailing.OpeningBalance <> 0
				Or Column.Value.Detailing.Receipt <> 0
				Or Column.Value.Detailing.Demand <> 0
				Or Column.Value.Detailing.MinInventory <> 0
				Or Column.Value.Detailing.MaxInventory <> 0
				Or Column.Value.Detailing.ClosingBalance <> 0 Then
				
				IndicatorsFilled = True;
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return IndicatorsFilled;
	
EndFunction

&AtServer
Procedure CalculateInventoryFlowCalendar(TableQueryResult)
	
	For Each RowResultQuery In TableQueryResult Do
		
		If RowResultQuery.OrderBalance <= 0 Then
			Continue;
		EndIf;
		
		CountOrderBalance		= RowResultQuery.OrderBalance;
		QuantityBalanceReceipt	= RowResultQuery.OrderBalance;
		QuantityBalanceNeedFor	= RowResultQuery.OrderBalance;
		
		SearchStructure = New Structure();
		SearchStructure.Insert("Products", RowResultQuery.Products);
		SearchStructure.Insert("Characteristic", RowResultQuery.Characteristic);
		SearchStructure.Insert("Order", RowResultQuery.Order);
		
		ResultOrders = TableQueryResult.FindRows(SearchStructure);
		For Each OrdersString In ResultOrders Do
			
			// The supplies are overdue.
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Receipt Then
				
				QuantityBalanceReceipt = QuantityBalanceReceipt - OrdersString.Receipt;
				
			EndIf;
			
			If OrdersString.Receipt <> 0 Then
				
				// Receipt.
				Receipt = min(CountOrderBalance, OrdersString.Receipt);
				CountOrderBalance = CountOrderBalance - OrdersString.Receipt;
				OrdersString.Receipt = Receipt;
				
			EndIf;
			
			// The demand is overdue.
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Shipment Then
				
				QuantityBalanceNeedFor = QuantityBalanceNeedFor - OrdersString.Demand;
				
			EndIf;
			
			If OrdersString.Demand <> 0 Then
				
				// Demand.
				Demand = min(CountOrderBalance, OrdersString.Demand);
				CountOrderBalance = CountOrderBalance - OrdersString.Demand;
				OrdersString.Demand = Demand;
				
			EndIf;
			
			OrdersString.OrderBalance = 0;
			
		EndDo;
		
		For Each OrdersString In ResultOrders Do
			
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Receipt Then
				
				If QuantityBalanceReceipt > 0 Then
					OrdersString.ReceiptOverdue = QuantityBalanceReceipt;
					QuantityBalanceReceipt = 0;
				EndIf;
				
			EndIf;
			
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Shipment Then
				
				If QuantityBalanceNeedFor > 0 Then
					OrdersString.NeedOverdue = QuantityBalanceNeedFor;
					QuantityBalanceNeedFor = 0;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddDrillDownByOrder(TableQueryResult, TableLineNeeds)
	
	TableLineNeeds.Columns.Add("OrderDetails");
	
	NewRow = Undefined;
	PreviousRecordPeriod = Undefined;
	ProductsPreviousRecord = Undefined;
	PreviousRecordCharacteristic = Undefined;
	
	For Each RowQueryResult In TableQueryResult Do
		
		If RowQueryResult.Period = PreviousRecordPeriod
			And RowQueryResult.Products = ProductsPreviousRecord 
			And RowQueryResult.Characteristic = PreviousRecordCharacteristic Then
			
			IndicatorsStructure = New Structure;
			IndicatorsStructure.Insert("Period", "Period" + Format(RowQueryResult.Period, "DF=yyyyMMdd"));
			IndicatorsStructure.Insert("Receipt", RowQueryResult.Receipt);
			IndicatorsStructure.Insert("ReceiptOverdue", RowQueryResult.ReceiptOverdue);
			IndicatorsStructure.Insert("Demand", RowQueryResult.Demand);
			IndicatorsStructure.Insert("NeedOverdue", RowQueryResult.NeedOverdue);
			IndicatorsStructure.Insert("Document", RowQueryResult.Order);
			IndicatorsStructure.Insert("SalesOrder", RowQueryResult.SalesOrder);
			
			CorrespondenceNewRow = NewRow.OrderDetails;
			CorrespondenceNewRow.Insert(RowQueryResult.Order, IndicatorsStructure);
			NewRow.OrderDetails = CorrespondenceNewRow; 
			
			NewRow.Receipt = NewRow.Receipt + RowQueryResult.Receipt;
			NewRow.ReceiptOverdue = NewRow.ReceiptOverdue + RowQueryResult.ReceiptOverdue;
			
			NewRow.Demand = NewRow.Demand + RowQueryResult.Demand;
			NewRow.NeedOverdue = NewRow.NeedOverdue + RowQueryResult.NeedOverdue;
			
		Else
			
			NewRow = TableLineNeeds.Add();
			FillPropertyValues(NewRow, RowQueryResult);
			
			IndicatorsStructure = New Structure;
			IndicatorsStructure.Insert("Period", "Period" + Format(RowQueryResult.Period, "DF=yyyyMMdd"));
			IndicatorsStructure.Insert("Receipt", RowQueryResult.Receipt);
			IndicatorsStructure.Insert("ReceiptOverdue", RowQueryResult.ReceiptOverdue);
			IndicatorsStructure.Insert("Demand", RowQueryResult.Demand);
			IndicatorsStructure.Insert("NeedOverdue", RowQueryResult.NeedOverdue);
			IndicatorsStructure.Insert("Document", RowQueryResult.Order);
			IndicatorsStructure.Insert("SalesOrder", RowQueryResult.SalesOrder);
			
			OrderDetailsMap = New Map;
			OrderDetailsMap.Insert(RowQueryResult.Order, IndicatorsStructure); 
			
			NewRow.OrderDetails = OrderDetailsMap;
			
			PreviousRecordPeriod = RowQueryResult.Period;
			ProductsPreviousRecord = RowQueryResult.Products;
			PreviousRecordCharacteristic = RowQueryResult.Characteristic;
			
		EndIf;
		
	EndDo;
	
	TableQueryResult = Undefined;
	
EndProcedure

&AtServer
Procedure UpdateRecommendationsAtServer()
	
	// Clearing the result before update.
	RecommendationsItems = Recommendations.GetItems();
	RecommendationsItems.Clear();
	
	TSInventory = GetFromTempStorage(AddressInventory);
	
	DataSource = New ValueTable;
	DataSource.Columns.Add("RowIndex", New TypeDescription("Number"));
	DataSource.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	DataSource.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	DataSource.Columns.Add("Vendor", New TypeDescription("CatalogRef.Counterparties"));
	DataSource.Columns.Add("ReplenishmentMethod", New TypeDescription("EnumRef.InventoryReplenishmentMethods"));
	DataSource.Columns.Add("ReplenishmentDeadline", New TypeDescription("Number"));
	DataSource.Columns.Add("ReplenishmentMethodPrecision", New TypeDescription("Number"));
	DataSource.Columns.Add("Quantity", New TypeDescription("Number"));
	DataSource.Columns.Add("ReceiptDate", New TypeDescription("Date"));
	DataSource.Columns.Add("SalesOrder", New TypeDescription("DocumentRef.SalesOrder"));
	
	CopyDataSourceRow = DataSource.CopyColumns().Add();
	
	RowIndex = 0;
	
	For Each Products In TSInventory.Rows Do
		
		If Products.Deficit > 0 Then
			
			If Not IsRecommendationNeed(Products) Then
				Continue;
			EndIf;
			
			CurrentPeriod = BegOfDay(CurrentSessionDate());
			
			MaxQuantity = 0;
			
			While BegOfDay(CurrentPeriod) <= BegOfDay(EndOfPeriod) Do
				
				ColumnName = "Period" + Format(CurrentPeriod, "DF=yyyyMMdd");
				
				If Products[ColumnName] > 0 Or Products.Overdue > 0 And CurrentPeriod = BegOfDay(CurrentSessionDate()) Then
					
					Quantity = Products[ColumnName];
					
					ProductsAttributes = Common.ObjectAttributesValues(Products.Products,
						"Vendor, Subcontractor, ReplenishmentMethod, ReplenishmentDeadline");
					
					If RecommendationsMode = 1 Then
						
						If (Quantity - MaxQuantity) > 0 Then
							
							Quantity = Quantity - MaxQuantity;
							MaxQuantity = Products[ColumnName];
							
							NewRow = DataSource.Add();
							NewRow.RowIndex = RowIndex;
							NewRow.Products = Products.Products;
							NewRow.Characteristic = Products.Characteristic;
							NewRow.Vendor = ?(ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing
								And CanReceiveSubcontractingServices, ProductsAttributes.Subcontractor, ProductsAttributes.Vendor);
							NewRow.ReplenishmentMethod = ProductsAttributes.ReplenishmentMethod;
							NewRow.ReplenishmentDeadline = ProductsAttributes.ReplenishmentDeadline;
							NewRow.ReplenishmentMethodPrecision = 1;
							NewRow.SalesOrder = GetSalesOrder(Products, ColumnName); 
							NewRow.Quantity = Quantity;
							NewRow.ReceiptDate = CurrentPeriod;
							
							AddAdditionalReplenishmentMethodRows(DataSource, NewRow.ReplenishmentMethod);
							
							RowIndex = RowIndex + 1;
							
						EndIf;
						
					Else
						
						CopyDataSourceRow.RowIndex = RowIndex;
						CopyDataSourceRow.Products = Products.Products;
						CopyDataSourceRow.Characteristic = Products.Characteristic;
						CopyDataSourceRow.Vendor = ?(ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing
							And CanReceiveSubcontractingServices, ProductsAttributes.Subcontractor, ProductsAttributes.Vendor);
						CopyDataSourceRow.ReplenishmentMethod = ProductsAttributes.ReplenishmentMethod;
						CopyDataSourceRow.ReplenishmentDeadline = ProductsAttributes.ReplenishmentDeadline;
						CopyDataSourceRow.ReplenishmentMethodPrecision = 1;
						CopyDataSourceRow.SalesOrder = GetSalesOrder(Products, ColumnName); 
						CopyDataSourceRow.Quantity = Quantity;
						CopyDataSourceRow.ReceiptDate = BegOfDay(EndOfPeriod);
						
					EndIf;
					
				EndIf;
				
				CurrentPeriod = CurrentPeriod + 86400;
				
			EndDo;
			
			If RecommendationsMode = 0 And CopyDataSourceRow.Quantity > 0 Then
				
				FillPropertyValues(DataSource.Add(), CopyDataSourceRow);
				
				AddAdditionalReplenishmentMethodRows(DataSource, CopyDataSourceRow.ReplenishmentMethod);
				
				RowIndex = RowIndex + 1;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If DataSource.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DataSource.RowIndex AS RowIndex,
	|	DataSource.ReplenishmentMethodPrecision AS ReplenishmentMethodPrecision,
	|	DataSource.Products AS Products,
	|	DataSource.Characteristic AS Characteristic,
	|	DataSource.Vendor AS Vendor,
	|	DataSource.ReplenishmentMethod AS ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline AS ReplenishmentDeadline,
	|	DataSource.Quantity AS Quantity,
	|	DataSource.SalesOrder AS SalesOrder,
	|	DataSource.ReceiptDate AS ReceiptDate
	|INTO DataSource
	|FROM
	|	&DataSource AS DataSource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TableCounterpartyPrices.Products AS Products,
	|	TableCounterpartyPrices.Characteristic AS Characteristic,
	|	ISNULL(PricesProductsCharacteristics.SupplierPriceTypes, PricesProducts.SupplierPriceTypes) AS PriceKind,
	|	ISNULL(PricesProductsCharacteristics.Counterparty, PricesProducts.Counterparty) AS Vendor,
	|	ISNULL(PricesProductsCharacteristics.Price, ISNULL(PricesProducts.Price, 0)) AS Price,
	|	ISNULL(PricesProductsCharacteristics.MeasurementUnit, ISNULL(PricesProducts.MeasurementUnit, VALUE(Catalog.UOMClassifier.EmptyRef))) AS MeasurementUnit
	|INTO DataSourcePrices
	|FROM
	|	DataSource AS TableCounterpartyPrices
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ProcessingDate,
	|				(Products, Characteristic) IN
	|					(SELECT
	|						DataSource.Products AS Products,
	|						DataSource.Characteristic AS Characteristic
	|					FROM
	|						DataSource AS DataSource)) AS PricesProductsCharacteristics
	|		ON TableCounterpartyPrices.Products = PricesProductsCharacteristics.Products
	|			AND TableCounterpartyPrices.Characteristic = PricesProductsCharacteristics.Characteristic
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ProcessingDate,
	|				(Products, Characteristic) IN
	|					(SELECT
	|						DataSource.Products AS Products,
	|						VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic
	|					FROM
	|						DataSource AS DataSource)) AS PricesProducts
	|		ON TableCounterpartyPrices.Products = PricesProducts.Products
	|			AND (PricesProducts.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))
	|WHERE
	|	ISNULL(PricesProductsCharacteristics.Actuality, ISNULL(PricesProducts.Actuality, FALSE))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TableCounterpartyPrices.Products AS Products,
	|	TableCounterpartyPrices.Characteristic AS Characteristic,
	|	TableCounterpartyPrices.PriceKind AS PriceKind,
	|	TableCounterpartyPrices.Vendor AS Vendor,
	|	CatalogSupplierPriceTypes.PriceCurrency AS PriceCurrency,
	|	TableCounterpartyPrices.Price / ISNULL(CatalogUOM.Factor, 1) AS Price
	|INTO DataSourcePricesCounterparties
	|FROM
	|	DataSourcePrices AS TableCounterpartyPrices
	|		LEFT JOIN Catalog.SupplierPriceTypes AS CatalogSupplierPriceTypes
	|		ON TableCounterpartyPrices.PriceKind = CatalogSupplierPriceTypes.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableCounterpartyPrices.MeasurementUnit = CatalogUOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DataSource.RowIndex AS RowIndex,
	|	DataSource.ReplenishmentMethodPrecision AS ReplenishmentMethodPrecision,
	|	DataSource.Products AS Products,
	|	DataSource.Characteristic AS Characteristic,
	|	DataSource.Vendor AS Vendor,
	|	DataSource.ReplenishmentMethod AS ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline AS ReplenishmentDeadline,
	|	DataSource.Quantity AS Quantity,
	|	DataSource.ReceiptDate AS ReceiptDate,
	|	DataSourcePricesCounterparties.PriceKind AS PriceKind,
	|	DataSourcePricesCounterparties.PriceCurrency AS PriceCurrency,
	|	ISNULL(DataSourcePricesCounterparties.Price, 0) AS Price,
	|	DataSource.SalesOrder AS SalesOrder
	|FROM
	|	DataSource AS DataSource
	|		LEFT JOIN DataSourcePricesCounterparties AS DataSourcePricesCounterparties
	|		ON DataSource.Vendor = DataSourcePricesCounterparties.Vendor
	|			AND DataSource.Products = DataSourcePricesCounterparties.Products
	|			AND DataSource.Characteristic = DataSourcePricesCounterparties.Characteristic
	|			AND (DataSource.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DataSource.RowIndex,
	|	DataSource.ReplenishmentMethodPrecision,
	|	DataSource.Products,
	|	DataSource.Characteristic,
	|	DataSource.Vendor,
	|	DataSource.ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline,
	|	DataSource.Quantity,
	|	DataSource.ReceiptDate,
	|	DataSourcePricesCounterparties.PriceKind,
	|	DataSourcePricesCounterparties.PriceCurrency,
	|	ISNULL(DataSourcePricesCounterparties.Price, 0),
	|	DataSource.SalesOrder
	|FROM
	|	DataSource AS DataSource
	|		LEFT JOIN DataSourcePricesCounterparties AS DataSourcePricesCounterparties
	|		ON DataSource.Vendor = DataSourcePricesCounterparties.Vendor
	|			AND DataSource.Products = DataSourcePricesCounterparties.Products
	|			AND (DataSourcePricesCounterparties.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))
	|			AND (DataSource.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase))
	|WHERE
	|	ISNULL(DataSourcePricesCounterparties.Price, 0) <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DataSource.RowIndex,
	|	DataSource.ReplenishmentMethodPrecision,
	|	DataSource.Products,
	|	DataSource.Characteristic,
	|	DataSourcePricesCounterparties.Vendor,
	|	DataSource.ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline,
	|	DataSource.Quantity,
	|	DataSource.ReceiptDate,
	|	DataSourcePricesCounterparties.PriceKind,
	|	DataSourcePricesCounterparties.PriceCurrency,
	|	ISNULL(DataSourcePricesCounterparties.Price, 0),
	|	DataSource.SalesOrder
	|FROM
	|	DataSource AS DataSource
	|		LEFT JOIN DataSourcePricesCounterparties AS DataSourcePricesCounterparties
	|		ON DataSource.Vendor <> DataSourcePricesCounterparties.Vendor
	|			AND DataSource.Products = DataSourcePricesCounterparties.Products
	|			AND DataSource.Characteristic = DataSourcePricesCounterparties.Characteristic
	|			AND (DataSource.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase))
	|WHERE
	|	ISNULL(DataSourcePricesCounterparties.Price, 0) <> 0
	|
	|ORDER BY
	|	RowIndex,
	|	ReplenishmentMethodPrecision,
	|	Order,
	|	PriceKind");
	
	Query.SetParameter("DataSource", DataSource);
	Query.SetParameter("ProcessingDate", BegOfDay(CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	ProductsItems = Recommendations.GetItems();
	
	RowCurrentIndex = Undefined;
	While Selection.Next() Do
		
		// 1. Adding products.
		If RowCurrentIndex <> Selection.RowIndex Then
			
			RowCurrentIndex = Selection.RowIndex;
			
			NewProducts = ProductsItems.Add();
			NewProducts.Products = Selection.Products;
			NewProducts.CharacteristicInventoryReplenishmentSource = Selection.Characteristic;
			NewProducts.ReplenishmentDeadline = Selection.ReplenishmentDeadline;
			NewProducts.Quantity = Selection.Quantity;
			NewProducts.ReceiptDate = Max(BegOfDay(CurrentSessionDate()) + Selection.ReplenishmentDeadline * 86400,
				Selection.ReceiptDate);
			NewProducts.ReceiptDateExpired = True;
			
			NewProducts.EditAllowed = False;
			
		EndIf;
		
		// 2. Adding replenishment method and prices.
		ReplenishmentMethodItems = NewProducts.GetItems();
		NewReplenishmentMethod = ReplenishmentMethodItems.Add();
		
		If Selection.ReplenishmentMethodPrecision = 1 Then
			NewReplenishmentMethod.Products = String(Selection.ReplenishmentMethod)
				+ " ("
				+ NStr("en = 'Default'; ru = 'По умолчанию';pl = 'Domyślnie';es_ES = 'Por defecto';es_CO = 'Por defecto';tr = 'Varsayılan';it = 'Predefinito';de = 'Standard'")
				+ ")";
		Else
			NewReplenishmentMethod.Products = String(Selection.ReplenishmentMethod);
		EndIf;
		
		NewReplenishmentMethod.ReplenishmentMethod = Selection.ReplenishmentMethod;
		NewReplenishmentMethod.ReplenishmentMethodPrecision = Selection.ReplenishmentMethodPrecision;
		NewReplenishmentMethod.Quantity = Selection.Quantity;
		NewReplenishmentMethod.ReplenishmentDeadline = Selection.ReplenishmentDeadline;
		NewReplenishmentMethod.ReceiptDate = Max(BegOfDay(CurrentSessionDate()) + Selection.ReplenishmentDeadline * 86400,
			Selection.ReceiptDate);
		NewReplenishmentMethod.ReceiptDateExpired = NewReplenishmentMethod.ReceiptDate > Selection.ReceiptDate;
		NewReplenishmentMethod.EditAllowed = True;
		NewReplenishmentMethod.SalesOrder = Selection.SalesOrder;
		
		If Selection.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
			
			NewReplenishmentMethod.CharacteristicInventoryReplenishmentSource = Selection.Vendor;
			NewReplenishmentMethod.Price = Selection.Price;
			NewReplenishmentMethod.Amount = Selection.Price * Selection.Quantity;
			NewReplenishmentMethod.Currency = Selection.PriceCurrency;
			NewReplenishmentMethod.PriceKind = Selection.PriceKind;
			
		ElsIf Selection.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing Then
			 NewReplenishmentMethod.CharacteristicInventoryReplenishmentSource = Selection.Vendor;
		EndIf;
		
		// 3. Formatting parameters.
		If Not NewReplenishmentMethod.ReceiptDateExpired Then
			
			NewProducts.ReceiptDateExpired = False;
			NewProducts.DemandClosed = True;
			
			If Not NewProducts.Selected Then
				
				NewReplenishmentMethod.Selected = True;
				NewProducts.Selected = True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	DataSource = Undefined;
	
EndProcedure

&AtServer
Procedure AddAdditionalReplenishmentMethodRows(DataSource, ReplenishmentMethod)
	
	NewRow = DataSource[DataSource.Count() - 1];
	EmptyCounterparties = Catalogs.Counterparties.EmptyRef();
	
	ProductsAttributes = Common.ObjectAttributesValues(NewRow.Products,
		"Vendor, Subcontractor");
				
	If ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
		
		// begin Drive.FullVersion
		If ProductionAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
			
		EndIf;
		// end Drive.FullVersion

		If SubcontractingAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 4;
			
			NewReplenishmentMethod.Vendor = ProductsAttributes.Subcontractor;
		EndIf;
		
	ElsIf ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
		
		NewReplenishmentMethod = DataSource.Add();
		FillPropertyValues(NewReplenishmentMethod, NewRow);
		NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly;
		NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
		
		If PurchasesAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
			
			NewReplenishmentMethod.Vendor = ProductsAttributes.Vendor;
		
		EndIf;
		
		If SubcontractingAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 4;
			
			NewReplenishmentMethod.Vendor = ProductsAttributes.Subcontractor;
			
		EndIf;
		
	ElsIf ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
		
		NewReplenishmentMethod = DataSource.Add();
		FillPropertyValues(NewReplenishmentMethod, NewRow);
		NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
		NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
		
		If PurchasesAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
			
			NewReplenishmentMethod.Vendor = ProductsAttributes.Vendor;
			
		EndIf;
		
		If SubcontractingAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 4;
			
			NewReplenishmentMethod.Vendor = ProductsAttributes.Subcontractor;
			
		EndIf;
		
	Else
		
		If PurchasesAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
			NewReplenishmentMethod.Vendor = ProductsAttributes.Vendor;
			
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
		
		EndIf;
		
		// begin Drive.FullVersion
		If ProductionAvailable Then
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
			NewReplenishmentMethod.Vendor = EmptyCounterparties;
			
			NewReplenishmentMethod = DataSource.Add();
			FillPropertyValues(NewReplenishmentMethod, NewRow);
			NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
			NewReplenishmentMethod.ReplenishmentMethodPrecision = 4;
			NewReplenishmentMethod.Vendor = EmptyCounterparties;
			
		EndIf;
		// end Drive.FullVersion

	EndIf;
	
EndProcedure

&AtServer
Function IsRecommendationNeed(ProductsRow)
	
	// begin Drive.FullVersion
	Balances = ProductsRow.Rows;
	
	For Each Balance In Balances Do
		
		If Not Balance.IsDispatchHeader Then
			Continue;
		EndIf;
		
		For Each DocumentRow In Balance.Rows Do
			
			If TypeOf(DocumentRow.Products) <> Type("DocumentRef.ManufacturingOperation") Then
				Continue;
			EndIf;
			
			Query = New Query;
			Query.Text = 
			"SELECT TOP 1
			|	BillsOfMaterialsContent.ManufacturedInProcess AS ManufacturedInProcess
			|FROM
			|	Document.ManufacturingOperation AS ManufacturingOperation
			|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
			|		ON ManufacturingOperation.Specification = BillsOfMaterialsContent.Ref
			|			AND (&Products = BillsOfMaterialsContent.Products)
			|			AND (&Characteristic = BillsOfMaterialsContent.Characteristic)
			|WHERE
			|	ManufacturingOperation.Ref = &Ref";
			
			Query.SetParameter("Ref", DocumentRow.Products);
			Query.SetParameter("Products", ProductsRow.Products);
			Query.SetParameter("Characteristic", ProductsRow.Characteristic);
			
			QueryResult = Query.Execute();
			
			Selection = QueryResult.Select();
			
			If Selection.Next() Then
				Return Not Selection.ManufacturedInProcess;
			EndIf;
		
		EndDo;
		
	EndDo;
	// end Drive.FullVersion
	
	Return True; // This handler is empty in Trade version.
	
EndFunction

&AtServer
Function GetSalesOrder(ProductsRow, ColumnName)
	
	Balances = ProductsRow.Rows;
	
	For Each Balance In Balances Do
		
		If Not Balance.IsDispatchHeader Then
			Continue;
		EndIf;
		
		For Each DocumentRow In Balance.Rows Do
			
			If DocumentRow[ColumnName] > 0 Then
				Return DocumentRow.SalesOrder;
			EndIf;
		
		EndDo;
		
	EndDo;
	
EndFunction

&AtServer
Function PrepareOrdersTables()
	
	OrdersSelected = False;
	
	OrdersTable = New ValueTable;
	OrdersTable.Columns.Add("ReplenishmentMethod",		New TypeDescription("EnumRef.InventoryReplenishmentMethods"));
	OrdersTable.Columns.Add("Counterparty",				New TypeDescription("CatalogRef.Counterparties"));
	OrdersTable.Columns.Add("PriceKind",				New TypeDescription("CatalogRef.SupplierPriceTypes"));
	OrdersTable.Columns.Add("Currency",					New TypeDescription("CatalogRef.Currencies"));
	OrdersTable.Columns.Add("Products",					New TypeDescription("CatalogRef.Products"));
	OrdersTable.Columns.Add("Characteristic",			New TypeDescription("CatalogRef.ProductsCharacteristics"));
	OrdersTable.Columns.Add("ReplenishmentDeadline",	New TypeDescription("Number"));
	OrdersTable.Columns.Add("ReceiptDate",				New TypeDescription("Date"));
	OrdersTable.Columns.Add("Quantity",					New TypeDescription("Number"));
	OrdersTable.Columns.Add("Price",					New TypeDescription("Number"));
	OrdersTable.Columns.Add("Amount",					New TypeDescription("Number"));
	OrdersTable.Columns.Add("SalesOrder",				New TypeDescription("DocumentRef.SalesOrder"));
	
	RecommendationsProducts = Recommendations.GetItems();
	For Each RecommendationRow In RecommendationsProducts Do
		
		ProductsItems = RecommendationRow.GetItems();
		For Each ProductsRow In ProductsItems Do
			
			If ProductsRow.Selected Then
				
				OrdersSelected = True;
				
				If Not ProductsRow.OrderGenerated Then
					
					NewRow = OrdersTable.Add();
					NewRow.ReplenishmentMethod = ProductsRow.ReplenishmentMethod;
					NewRow.Counterparty = ProductsRow.CharacteristicInventoryReplenishmentSource;
					NewRow.PriceKind = ProductsRow.PriceKind;
					NewRow.Currency = ProductsRow.Currency;
					NewRow.Products = RecommendationRow.Products;
					NewRow.Characteristic = RecommendationRow.CharacteristicInventoryReplenishmentSource;
					NewRow.ReplenishmentDeadline = RecommendationRow.ReplenishmentDeadline;
					NewRow.ReceiptDate = ProductsRow.ReceiptDate;
					NewRow.Quantity = ProductsRow.Quantity;
					NewRow.Price = ProductsRow.Price;
					NewRow.SalesOrder = ProductsRow.SalesOrder;
					
					ProductsRow.OrderGenerated = True;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If OrdersTable.Count() = 0 And OrdersSelected Then
		CommonClientServer.MessageToUser(NStr("en = 'For the selected recommendations, orders have already been generated.'; ru = 'Для выбранных рекомендаций уже сформированы заказы.';pl = 'Dla wybranych poleceń, zamówienia są już wygenerowane.';es_ES = 'Ya se han generado órdenes para las recomendaciones seleccionadas.';es_CO = 'Ya se han generado órdenes para las recomendaciones seleccionadas.';tr = 'Seçilen öneriler için siparişler zaten oluşturuldu.';it = 'Gli ordini sono già stati generati per le raccomandazioni selezionate.';de = 'Aufträge wurden für die ausgewählten Empfehlungen bereits generiert.'"));
	EndIf;
	
	FilterStructure = New Structure("ReplenishmentMethod", Enums.InventoryReplenishmentMethods.Purchase);
	PurchOrdersTable = OrdersTable.Copy(FilterStructure);
	FilterStructure.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
	ProcessingOrdersTable = OrdersTable.Copy(FilterStructure);
	
	Result = New Structure;
	Result.Insert("ProcessingOrdersTable", ProcessingOrdersTable);
	Result.Insert("PurchOrdersTable", PurchOrdersTable);
	
	// begin Drive.FullVersion
	
	FilterStructure = New Structure("ReplenishmentMethod", Enums.InventoryReplenishmentMethods.Production);
	ProductionOrdersTable = OrdersTable.Copy(FilterStructure);
	Result.Insert("ProductionOrdersTable", ProductionOrdersTable);
	
	FilterStructure = New Structure("ReplenishmentMethod", Enums.InventoryReplenishmentMethods.Assembly);
	AssemblyProductionOrdersTable = OrdersTable.Copy(FilterStructure);
	Result.Insert("AssemblyProductionOrdersTable", AssemblyProductionOrdersTable);
	
	// end Drive.FullVersion
	
	Return Result;
	
EndFunction

&AtServer
Procedure GenerateOrdersAtServer()
	
	OrdersTables = PrepareOrdersTables();
	
	GeneratePurchaseOrders(OrdersTables.PurchOrdersTable);
	
	If CanReceiveSubcontractingServices Then
		GenerateSubcontractorOrders(OrdersTables.ProcessingOrdersTable);
	Else
		GeneratePurchaseOrders(OrdersTables.ProcessingOrdersTable);
	EndIf;
	
	// begin Drive.FullVersion
	GenerateProductionOrders(OrdersTables.ProductionOrdersTable);
	GenerateAssemblyProductionOrders(OrdersTables.AssemblyProductionOrdersTable);
	// end Drive.FullVersion
	
EndProcedure

&AtServer
Procedure GeneratePurchaseOrders(PurchOrdersTable)
	
	If PurchOrdersTable.Count() = 0 Then
		Return;
	EndIf;
	
	DocumentCurrencyDefault = DriveReUse.GetFunctionalCurrency();
	DataCurrency = CurrencyRateOperations.GetCurrencyRate(CurrentSessionDate(), DocumentCurrencyDefault, Company);
	ExchangeRateDefault = DataCurrency.Rate;
	RepetitionDefault = DataCurrency.Repetition;
	
	ReceiptDateInHead = DriveReUse.AttributeInHeader("ReceiptDatePositionInPurchaseOrder");
	
	If SetOrderStatusInProgress Then
		PurchaseOrdersInProgressStatus = Constants.PurchaseOrdersInProgressStatus.Get();
		If Not ValueIsFilled(PurchaseOrdersInProgressStatus) Then
			PurchaseOrdersInProgressStatus = GetOrderInProgressStatus("PurchaseOrder");
		EndIf;
	EndIf;
	
	ColumnsList = "ReplenishmentMethod";
	
	If ReceiptDateInHead Then
		ColumnsList = ColumnsList + ", ReceiptDate";
	EndIf;
	
	If UseGroupProductsBySupplier Then
		ColumnsList = ColumnsList + ", Counterparty, PriceKind, Currency";
	EndIf;
	
	PurchOrdersHeaders = PurchOrdersTable.Copy(, ColumnsList);
	PurchOrdersHeaders.GroupBy(ColumnsList);
	
	For Each OrderHeader In PurchOrdersHeaders Do
		
		PostingPossibility = UseGroupProductsBySupplier;
		
		NewOrder = Documents.PurchaseOrder.CreateDocument();
		
		NewOrder.Date = CurrentSessionDate();
		NewOrder.Company = Company;
		
		NewOrder.Fill(Undefined);
		
		If OrderHeader.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
			NewOrder.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForPurchase;
		Else
			NewOrder.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForProcessing;
		EndIf;
		
		StructureFillHeader = New Structure("Company", NewOrder.Company);
		DriveServer.FillDocumentHeader(NewOrder, , , , True, StructureFillHeader);
		
		NewOrder.DocumentCurrency = DocumentCurrencyDefault;
		NewOrder.ExchangeRate = ExchangeRateDefault;
		NewOrder.Multiplicity = RepetitionDefault;
		
		If SetOrderStatusInProgress Then
			NewOrder.OrderState = PurchaseOrdersInProgressStatus;
		EndIf;
		
		If UseGroupProductsBySupplier Then
			
			NewOrder.Counterparty = OrderHeader.Counterparty;
			NewOrder.Contract = DriveServer.GetContractByDefault(NewOrder.Ref,
				NewOrder.Counterparty,
				NewOrder.Company,
				NewOrder.OperationKind);
			
			NewOrder.VATTaxation = DriveServer.CounterpartyVATTaxation(
				NewOrder.Counterparty,
				DriveServer.VATTaxation(NewOrder.Company, NewOrder.Date));
			
			ContractAttributes = DriveServer.GetRefAttributes(NewOrder.Contract, "SettlementsCurrency, SupplierPriceTypes");
			
			If ValueIsFilled(OrderHeader.PriceKind) Then
				NewOrder.SupplierPriceTypes = OrderHeader.PriceKind;
				NewOrder.AmountIncludesVAT = Common.ObjectAttributeValue(OrderHeader.PriceKind, "PriceIncludesVAT");
			ElsIf ValueIsFilled(ContractAttributes.SupplierPriceTypes) Then
				NewOrder.SupplierPriceTypes = ContractAttributes.SupplierPriceTypes;
				NewOrder.AmountIncludesVAT = Common.ObjectAttributeValue(ContractAttributes.SupplierPriceTypes, "PriceIncludesVAT");
			EndIf;
			
			If ValueIsFilled(OrderHeader.Currency) Then
				NewOrder.DocumentCurrency = OrderHeader.Currency;
			ElsIf ValueIsFilled(ContractAttributes.SettlementsCurrency) Then
				NewOrder.DocumentCurrency = ContractAttributes.SettlementsCurrency;
			EndIf;
			
			If NewOrder.DocumentCurrency <> DocumentCurrencyDefault Then
				DataCurrency = CurrencyRateOperations.GetCurrencyRate(CurrentSessionDate(),
					NewOrder.DocumentCurrency,
					NewOrder.Company);
				NewOrder.ExchangeRate = DataCurrency.Rate;
				NewOrder.Multiplicity = DataCurrency.Repetition;
			EndIf;
			
		EndIf;
		
		If ReceiptDateInHead Then
			NewOrder.ReceiptDate = OrderHeader.ReceiptDate;
		EndIf;
		
		WorkWithVAT.ProcessingCompanyVATNumbers(NewOrder, "CompanyVATNumber");
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(NewOrder.Date, NewOrder.Company);
		
		SearchStructure = New Structure();
		SearchStructure.Insert("ReplenishmentMethod", OrderHeader.ReplenishmentMethod);
		
		If ReceiptDateInHead Then
			SearchStructure.Insert("ReceiptDate", OrderHeader.ReceiptDate);
		EndIf;
		
		If UseGroupProductsBySupplier Then
			SearchStructure.Insert("Counterparty", OrderHeader.Counterparty);
			SearchStructure.Insert("PriceKind", OrderHeader.PriceKind);
			SearchStructure.Insert("Currency", OrderHeader.Currency);
		EndIf;
		
		OrderRows = PurchOrdersTable.FindRows(SearchStructure);
		For Each OrderRow In OrderRows Do
			
			ProductsAttributes = DriveServer.GetRefAttributes(OrderRow.Products, "MeasurementUnit, VATRate");
			
			NewRow = NewOrder.Inventory.Add();
			NewRow.Products = OrderRow.Products;
			NewRow.Characteristic = OrderRow.Characteristic;
			NewRow.Quantity = OrderRow.Quantity;
			NewRow.MeasurementUnit = ProductsAttributes.MeasurementUnit;
			
			If NewOrder.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
				If ValueIsFilled(ProductsAttributes.VATRate) Then
					NewRow.VATRate = ProductsAttributes.VATRate;
				Else
					NewRow.VATRate = DefaultVATRate;
				EndIf;
				
			ElsIf NewOrder.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				NewRow.VATRate = Catalogs.VATRates.Exempt;
			Else
				NewRow.VATRate = Catalogs.VATRates.ZeroRate;
			EndIf;
			
			If UseGroupProductsBySupplier Then
				
				StructureData = New Structure;
				StructureData.Insert("Counterparty", OrderHeader.Counterparty);
				StructureData.Insert("Products", NewRow.Products);
				StructureData.Insert("Characteristic", NewRow.Characteristic);
				Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureData);
				StructureData.Property("CrossReference", NewRow.CrossReference);
				
				If ValueIsFilled(OrderHeader.PriceKind) Then
					
					VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
					
					NewRow.Price = OrderRow.Price;
					NewRow.Amount = NewRow.Price * NewRow.Quantity;
					NewRow.VATAmount = ?(NewOrder.AmountIncludesVAT,
						NewRow.Amount - NewRow.Amount / ((VATRate + 100) / 100),
						NewRow.Amount * VATRate / 100);
					NewRow.Total = NewRow.Amount + ?(NewOrder.AmountIncludesVAT, 0, NewRow.VATAmount);
					
				EndIf;
				
			EndIf;
			
			NewRow.ReceiptDate = OrderRow.ReceiptDate;
			
			If NewOrder.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForProcessing Then
				
				ProductsReplenishmentMethod = Common.ObjectAttributeValue(NewRow.Products, "ReplenishmentMethod"); 
				If ProductsReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
					NewRow.Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(NewRow.Products,
						NewOrder.Date, 
						NewRow.Characteristic,
						Enums.OperationTypesProductionOrder.Production);
				ElsIf ProductsReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
					NewRow.Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(NewRow.Products,
						NewOrder.Date, 
						NewRow.Characteristic,
						Enums.OperationTypesProductionOrder.Assembly);
				EndIf;
				
			EndIf;
			
			If PostingPossibility And NewRow.Price = 0 Then
				PostingPossibility = False;
			EndIf;
			
		EndDo;
		
		WriteNewOrder(NewOrder, PostingPossibility);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateSubcontractorOrders(SubcontractorOrdersTable)
	
	If SubcontractorOrdersTable.Count() = 0 Then
		Return;
	EndIf;
	
	IsGroupProductsBySubcontractor = IsGroupProductsBySubcontractor();
	
	DocumentCurrencyDefault = DriveReUse.GetFunctionalCurrency();
	DataCurrency = CurrencyRateOperations.GetCurrencyRate(CurrentSessionDate(), DocumentCurrencyDefault, Company);
	ExchangeRateDefault = DataCurrency.Rate;
	RepetitionDefault = DataCurrency.Repetition;
	
	If SetOrderStatusInProgress Then
		SubcontractorOrdersInProgressStatus = Constants.SubcontractorOrderIssuedInProgressStatus.Get();
		If Not ValueIsFilled(SubcontractorOrdersInProgressStatus) Then
			SubcontractorOrdersInProgressStatus = GetOrderInProgressStatus("SubcontractorOrderIssued");
		EndIf;
	EndIf;
	
	ColumnsList = "ReplenishmentMethod";
	
	If UseGroupProductsBySubcontractor And IsGroupProductsBySubcontractor Then
		ColumnsList = ColumnsList + ", Counterparty";
	EndIf;
	
	SubOrdersHeaders = SubcontractorOrdersTable.Copy(, ColumnsList);
	SubOrdersHeaders.GroupBy(ColumnsList);
	
	For Each OrderHeader In SubOrdersHeaders Do
		
		PostingPossibility = False;
		
		NewOrder = Documents.SubcontractorOrderIssued.CreateDocument();
		
		NewOrderDate = CurrentSessionDate();
		NewOrder.Date = NewOrderDate;
		NewOrder.Company = Company;
		
		NewOrder.Fill(Undefined);
		
		StructureFillHeader = New Structure("Company", NewOrder.Company);
		DriveServer.FillDocumentHeader(NewOrder, , , , True, StructureFillHeader);
		
		NewOrder.DocumentCurrency = DocumentCurrencyDefault;
		NewOrder.ExchangeRate = ExchangeRateDefault;
		NewOrder.Multiplicity = RepetitionDefault;
		
		If SetOrderStatusInProgress Then
			NewOrder.OrderState = SubcontractorOrdersInProgressStatus;
		EndIf;
		
		If UseGroupProductsBySubcontractor And IsGroupProductsBySubcontractor Then
			
			NewOrder.Counterparty = OrderHeader.Counterparty;
			
			ContractAttributes = Undefined;
			Attributes = "DoOperationsByContracts, VATTaxation, SettlementsCurrency, SupplierPriceTypes";
	
			DriveServer.ReadCounterpartyAttributes(ContractAttributes, OrderHeader.Counterparty, Attributes);
			
			If ValueIsFilled(OrderHeader.Counterparty) And ContractAttributes.DoOperationsByContracts Then 
				NewOrder.Contract = DriveServer.GetContractByDefault(NewOrder.Ref,
					NewOrder.Counterparty,
					NewOrder.Company);
			EndIf;
				
			NewOrder.VATTaxation = DriveServer.CounterpartyVATTaxation(
				NewOrder.Counterparty,
				DriveServer.VATTaxation(NewOrder.Company, NewOrder.Date));
			
			If ValueIsFilled(ContractAttributes.SettlementsCurrency) Then
				NewOrder.DocumentCurrency = ContractAttributes.SettlementsCurrency;
			ElsIf ValueIsFilled(DocumentCurrencyDefault) Then
				NewOrder.DocumentCurrency = DocumentCurrencyDefault;
			EndIf;
			
			If NewOrder.DocumentCurrency <> DocumentCurrencyDefault Then
				DataCurrency = CurrencyRateOperations.GetCurrencyRate(CurrentSessionDate(),
					NewOrder.DocumentCurrency,
					NewOrder.Company);
				NewOrder.ExchangeRate = DataCurrency.Rate;
				NewOrder.Multiplicity = DataCurrency.Repetition;
			EndIf;
			
		EndIf;
		
		WorkWithVAT.ProcessingCompanyVATNumbers(NewOrder, "CompanyVATNumber");
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(NewOrder.Date, NewOrder.Company);
		
		SearchStructure = New Structure();
		SearchStructure.Insert("ReplenishmentMethod", OrderHeader.ReplenishmentMethod);
		
		If UseGroupProductsBySubcontractor And IsGroupProductsBySubcontractor Then
			SearchStructure.Insert("Counterparty", OrderHeader.Counterparty);
		EndIf;
		
		OrderRows = SubcontractorOrdersTable.FindRows(SearchStructure);
		For Each OrderRow In OrderRows Do
			
			ProductsAttributes = DriveServer.GetRefAttributes(OrderRow.Products, "MeasurementUnit, VATRate, ReplenishmentMethod, ProductsType");
			
			NewRow = NewOrder.Products.Add();
			NewRow.Products = OrderRow.Products;
			NewRow.Characteristic = OrderRow.Characteristic;
			NewRow.Quantity = OrderRow.Quantity;
			NewRow.MeasurementUnit = ProductsAttributes.MeasurementUnit;
			
			NewRow.Specification = Documents.SubcontractorOrderIssued.GetAvailableBOM(ProductsAttributes, NewOrderDate, OrderRow, OrderRow.Characteristic);
			
			If NewOrder.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
				If ValueIsFilled(ProductsAttributes.VATRate) Then
					NewRow.VATRate = ProductsAttributes.VATRate;
				Else
					NewRow.VATRate = DefaultVATRate;
				EndIf;
				
			ElsIf NewOrder.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				NewRow.VATRate = Catalogs.VATRates.Exempt;
			Else
				NewRow.VATRate = Catalogs.VATRates.ZeroRate;
			EndIf;
			
		EndDo;
		
		NewOrder.FillTabularSectionBySpecificationForTheSalesOrder();
		
		WriteNewOrder(NewOrder, PostingPossibility);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteNewOrder(NewOrderObject, PostingPossibility = True)
	
	NewOrderObject.Comment = NStr("en = 'Automatically generated by the ""Demand planning"".'; ru = 'Сформирован автоматически обработкой ""Расчет потребностей в запасах"".';pl = 'Automatycznie generowane przez ""Planowanie zapotrzebowania"".';es_ES = 'Automáticamente generado por la ""Planificación de demanda"".';es_CO = 'Automáticamente generado por la ""Planificación de demanda"".';tr = '""Talep planlama"" tarafından otomatik olarak oluşturuldu.';it = 'Generato automaticamente da ""Calcolo del fabbisogno di scorte"".';de = 'Von der ""Bedarfsplanung"" automatisch generiert.'");
	
	Try
		
		NewOrderObject.Write(DocumentWriteMode.Write);
		
		GeneratedOrder = Orders.Add();
		GeneratedOrder.Order = NewOrderObject.Ref;
		GeneratedOrder.DefaultPicture = 0;
		GeneratedOrder.Status = NewOrderObject.OrderState;
		
		// begin Drive.FullVersion
		If TypeOf(NewOrderObject) = Type("DocumentObject.ProductionOrder") Then
			GeneratedOrder.LinkWIP = NStr("en = 'Generate Work-in-progress'; ru = 'Создать документ ""Незавершенное производство""';pl = 'Wygeneruj Pracę w toku';es_ES = 'Generar el Trabajo en progreso';es_CO = 'Generar el Trabajo en progreso';tr = 'İşlem bitişi oluştur';it = 'Creare Lavoro in corso';de = 'Arbeit in Bearbeitung generieren'");
		Else
		// end Drive.FullVersion
			GeneratedOrder.Supplier = NewOrderObject.Counterparty;
		// begin Drive.FullVersion
		EndIf;
		// end Drive.FullVersion

		If PostOrders And PostingPossibility Then
			NewOrderObject.Write(DocumentWriteMode.Posting);
			GeneratedOrder.DefaultPicture = 1;
		EndIf;
		
	Except
		
		If PostOrders And PostingPossibility Then
			StringPattern = NStr("en = 'Cannot post the %1 document.'; ru = 'Не удалось провести документ: %1.';pl = 'Nie można zatwierdzić dokumentu %1.';es_ES = 'No se puede enviar el %1 documento.';es_CO = 'No se puede enviar el %1 documento.';tr = '%1 belgesi kaydedilemiyor.';it = 'Impossibile pubblicare il documento %1.';de = 'Das %1 Dokument kann nicht gebucht werden.'");
		Else
			StringPattern = NStr("en = 'Cannot write the %1 document.'; ru = 'Не удалось записать документ %1.';pl = 'Nie można zapisać dokumentu %1.';es_ES = 'No se puede guardar el %1 documento.';es_CO = 'No se puede guardar el %1 documento.';tr = '%1 belgesi yazılamıyor.';it = 'Impossibile scrivere il documento %1.';de = 'Das %1 Dokument kann nicht gespeichert werden.'");
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			StringPattern,
			String(NewOrderObject));
		
		CommonClientServer.MessageToUser(MessageText);
		
	EndTry;
	
EndProcedure

// begin Drive.FullVersion

&AtServer
Procedure GenerateProductionOrders(ProductionOrdersTable)
	
	If ProductionOrdersTable.Count() = 0 Then
		Return;
	EndIf;
	
	If SetOrderStatusInProgress Then
		ProductionOrdersInProgressStatus = Constants.ProductionOrdersInProgressStatus.Get();
		If Not ValueIsFilled(ProductionOrdersInProgressStatus) Then
			ProductionOrdersInProgressStatus = GetOrderInProgressStatus("ProductionOrder");
		EndIf;
	EndIf;
	
	ProductionOrdersHeaders = ProductionOrdersTable.Copy(, "ReceiptDate, ReplenishmentDeadline");
	ProductionOrdersHeaders.GroupBy("ReceiptDate, ReplenishmentDeadline");
	
	For Each OrderHeader In ProductionOrdersHeaders Do
		
		PostingPossibility = True;
		
		NewOrder = Documents.ProductionOrder.CreateDocument();
		NewOrder.Date = CurrentSessionDate();
		NewOrder.OperationKind = Enums.OperationTypesProductionOrder.Production;
		
		DriveServer.FillDocumentHeader(NewOrder, , , , True);
		
		NewOrder.Company = Company;
		NewOrder.Start = OrderHeader.ReceiptDate - 86400 * OrderHeader.ReplenishmentDeadline;
		NewOrder.Finish = OrderHeader.ReceiptDate;
		NewOrder.Priority = Catalogs.ProductionOrdersPriorities.Medium;
		
		If SetOrderStatusInProgress Then
			NewOrder.OrderState = ProductionOrdersInProgressStatus;
		EndIf;
		
		If IncludeInProductionPlanning Then
			NewOrder.UseProductionPlanning = True;
		EndIf;
		
		SearchStructure = New Structure();
		SearchStructure.Insert("ReceiptDate", OrderHeader.ReceiptDate);
		SearchStructure.Insert("ReplenishmentDeadline", OrderHeader.ReplenishmentDeadline);
		
		OrderRows = ProductionOrdersTable.FindRows(SearchStructure);
		For Each OrderRow In OrderRows Do
			
			ProductsAttributes = DriveServer.GetRefAttributes(OrderRow.Products, "MeasurementUnit, ProductsType");
			
			NewRow = NewOrder.Products.Add();
			NewRow.Products = OrderRow.Products;
			NewRow.Characteristic = OrderRow.Characteristic;
			NewRow.Quantity = OrderRow.Quantity;
			NewRow.MeasurementUnit = ProductsAttributes.MeasurementUnit;
			NewRow.ProductsType = ProductsAttributes.ProductsType;
			NewRow.Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(NewRow.Products,
				NewOrder.Date,
				NewRow.Characteristic,
				NewOrder.OperationKind);
			
			If Not ValueIsFilled(NewRow.Specification) Then
				PostingPossibility = False;
			EndIf;
			
		EndDo;
		
		WriteNewOrder(NewOrder, PostingPossibility);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateAssemblyProductionOrders(ProductionOrdersTable)
	
	If ProductionOrdersTable.Count() = 0 Then
		Return;
	EndIf;
	
	If SetOrderStatusInProgress Then
		ProductionOrdersInProgressStatus = Constants.ProductionOrdersInProgressStatus.Get();
		If Not ValueIsFilled(ProductionOrdersInProgressStatus) Then
			ProductionOrdersInProgressStatus = GetOrderInProgressStatus("ProductionOrder");
		EndIf;
	EndIf;
	
	ProductionOrdersHeaders = ProductionOrdersTable.Copy(, "ReceiptDate, ReplenishmentDeadline");
	ProductionOrdersHeaders.GroupBy("ReceiptDate, ReplenishmentDeadline");
	
	For Each OrderHeader In ProductionOrdersHeaders Do
		
		PostingPossibility = True;
		
		NewOrder = Documents.ProductionOrder.CreateDocument();
		NewOrder.Date = CurrentSessionDate();
		NewOrder.OperationKind = Enums.OperationTypesProductionOrder.Assembly;
		
		DriveServer.FillDocumentHeader(NewOrder, , , , True);
		
		NewOrder.Company = Company;
		NewOrder.Start = OrderHeader.ReceiptDate - 86400 * OrderHeader.ReplenishmentDeadline;
		NewOrder.Finish = OrderHeader.ReceiptDate;
		NewOrder.Priority = Catalogs.ProductionOrdersPriorities.Medium;
		
		If SetOrderStatusInProgress Then
			NewOrder.OrderState = ProductionOrdersInProgressStatus;
		EndIf;
		
		SearchStructure = New Structure();
		SearchStructure.Insert("ReceiptDate", OrderHeader.ReceiptDate);
		SearchStructure.Insert("ReplenishmentDeadline", OrderHeader.ReplenishmentDeadline);
		
		OrderRows = ProductionOrdersTable.FindRows(SearchStructure);
		For Each OrderRow In OrderRows Do
			
			ProductsAttributes = DriveServer.GetRefAttributes(OrderRow.Products, "MeasurementUnit, ProductsType");
			
			NewRow = NewOrder.Products.Add();
			NewRow.Products = OrderRow.Products;
			NewRow.Characteristic = OrderRow.Characteristic;
			NewRow.Quantity = OrderRow.Quantity;
			NewRow.MeasurementUnit = ProductsAttributes.MeasurementUnit;
			NewRow.ProductsType = ProductsAttributes.ProductsType;
			NewRow.Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(NewRow.Products,
				NewOrder.Date,
				NewRow.Characteristic,
				NewOrder.OperationKind);
				
			If Not ValueIsFilled(NewRow.Specification) Then
				PostingPossibility = False;
			EndIf;
			
		EndDo;
		
		NewOrder.FillTabularSectionBySpecification();
		
		WriteNewOrder(NewOrder, PostingPossibility);
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function FullVersionQueryText()
	
	QueryText =
	"SELECT ALLOWED
	|	OrdersBalance.MovementType AS MovementType,
	|	OrdersBalance.Company AS Company,
	|	OrdersBalance.Products AS Products,
	|	CatalogProducts.ReplenishmentMethod AS ReplenishmentMethod,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Processing)
	|				AND &CanReceiveSubcontractingServices
	|			THEN CatalogProducts.Subcontractor
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	CASE
	|		WHEN NOT ManufacturingOperationInventory.Ref IS NULL
	|			THEN ManufacturingOperationInventory.Ref
	|		ELSE OrdersBalance.Order
	|	END AS Order,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance,
	|	OrdersBalance.SalesOrder AS SalesOrder
	|INTO TemporaryTableOrdersBalance
	|FROM
	|	(SELECT
	|		VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|		SalesOrdersBalances.Company AS Company,
	|		SalesOrdersBalances.Products AS Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN SalesOrdersBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		SalesOrdersBalances.SalesOrder AS Order,
	|		SalesOrdersBalances.QuantityBalance AS QuantityBalance,
	|		SalesOrdersBalances.SalesOrder AS SalesOrder
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS SalesOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Shipment),
	|		WorkOrdersBalances.Company,
	|		WorkOrdersBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN WorkOrdersBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		WorkOrdersBalances.WorkOrder,
	|		WorkOrdersBalances.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.WorkOrders.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS WorkOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryDemandBalances.MovementType,
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN InventoryDemandBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		CASE
	|			WHEN InventoryDemandBalances.ProductionDocument <> UNDEFINED
	|				THEN InventoryDemandBalances.ProductionDocument
	|			ELSE InventoryDemandBalances.SalesOrder
	|		END,
	|		InventoryDemandBalances.QuantityBalance,
	|		InventoryDemandBalances.SalesOrder
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&EndDate,
	|				Company = &Company
	|					AND VALUETYPE(SalesOrder) <> TYPE(Document.SubcontractorOrderReceived) {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS InventoryDemandBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Receipt),
	|		PurchaseOrdersBalances.Company,
	|		PurchaseOrdersBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN PurchaseOrdersBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		PurchaseOrdersBalances.PurchaseOrder,
	|		PurchaseOrdersBalances.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.PurchaseOrders.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS PurchaseOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Receipt),
	|		GoodsInvoicedNotReceivedBalance.Company,
	|		GoodsInvoicedNotReceivedBalance.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN GoodsInvoicedNotReceivedBalance.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		GoodsInvoicedNotReceivedBalance.PurchaseOrder,
	|		GoodsInvoicedNotReceivedBalance.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotReceived.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS GoodsInvoicedNotReceivedBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Receipt),
	|		ProductionOrdersBalances.Company,
	|		ProductionOrdersBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN ProductionOrdersBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		ProductionOrdersBalances.ProductionOrder,
	|		ProductionOrdersBalances.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.ProductionOrders.Balance(
	|				&DateBalance,
	|				Company = &Company
	|					AND VALUETYPE(ProductionOrder.SalesOrder) <> TYPE(Document.SubcontractorOrderReceived) {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS ProductionOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Receipt),
	|		SubcontractorOrdersIssuedBalances.Company,
	|		SubcontractorOrdersIssuedBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN SubcontractorOrdersIssuedBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		SubcontractorOrdersIssuedBalances.SubcontractorOrder,
	|		SubcontractorOrdersIssuedBalances.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.SubcontractorOrdersIssued.Balance(
	|				&DateBalance,
	|				Company = &Company
	|					AND VALUETYPE(SubcontractorOrder.BasisDocument) <> TYPE(Document.ManufacturingOperation) {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS SubcontractorOrdersIssuedBalances) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON OrdersBalance.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|			AND (CatalogProducts.ReplenishmentMethod IN (&ReplenishmentMethods))
	|		LEFT JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		ON OrdersBalance.Products = ManufacturingOperationInventory.Products
	|			AND OrdersBalance.Characteristic = ManufacturingOperationInventory.Characteristic
	|			AND OrdersBalance.Order = ManufacturingOperationInventory.Ref.BasisDocument
	|			AND (ManufacturingOperationInventory.Ref.Posted)
	|
	|GROUP BY
	|	OrdersBalance.Company,
	|	OrdersBalance.Products,
	|	CatalogProducts.ReplenishmentMethod,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.MovementType,
	|	CASE
	|		WHEN NOT ManufacturingOperationInventory.Ref IS NULL
	|			THEN ManufacturingOperationInventory.Ref
	|		ELSE OrdersBalance.Order
	|	END,
	|	OrdersBalance.SalesOrder,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Processing)
	|				AND &CanReceiveSubcontractingServices
	|			THEN CatalogProducts.Subcontractor
	|		ELSE CatalogProducts.Vendor
	|	END
	|
	|INDEX BY
	|	Company,
	|	Products,
	|	Characteristic,
	|	Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReorderPointSettings.Products AS Products,
	|	ReorderPointSettings.Characteristic AS Characteristic,
	|	ReorderPointSettings.InventoryMinimumLevel AS InventoryMinimumLevel,
	|	ReorderPointSettings.InventoryMaximumLevel AS InventoryMaximumLevel,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor
	|INTO ReorderPointsProductsCharacteristic
	|FROM
	|	InformationRegister.ReorderPointSettings AS ReorderPointSettings
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ReorderPointSettings.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.UseCharacteristics)
	|WHERE
	|	ReorderPointSettings.Company = &Company
	|	AND &UseCharacteristics
	|	AND ReorderPointSettings.Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReorderPointSettings.Products AS Products,
	|	ProductsCharacteristics.Ref AS Characteristic,
	|	ReorderPointSettings.InventoryMinimumLevel AS InventoryMinimumLevel,
	|	ReorderPointSettings.InventoryMaximumLevel AS InventoryMaximumLevel,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor
	|INTO ReorderPointsProducts
	|FROM
	|	InformationRegister.ReorderPointSettings AS ReorderPointSettings
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ReorderPointSettings.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.UseCharacteristics)
	|		INNER JOIN Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|		ON ReorderPointSettings.Products = ProductsCharacteristics.Owner
	|WHERE
	|	ReorderPointSettings.Company = &Company
	|	AND &UseCharacteristics
	|	AND ReorderPointSettings.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReorderPointSettings.Products AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	ReorderPointSettings.InventoryMinimumLevel AS InventoryMinimumLevel,
	|	ReorderPointSettings.InventoryMaximumLevel AS InventoryMaximumLevel,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor
	|INTO ReorderPointSettingsTable
	|FROM
	|	InformationRegister.ReorderPointSettings AS ReorderPointSettings
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ReorderPointSettings.Products = CatalogProducts.Ref
	|WHERE
	|	ReorderPointSettings.Company = &Company
	|	AND (NOT &UseCharacteristics
	|			OR NOT CatalogProducts.UseCharacteristics)
	|
	|UNION ALL
	|
	|SELECT
	|	ReorderPointsProductsCharacteristic.Products,
	|	ReorderPointsProductsCharacteristic.Characteristic,
	|	ReorderPointsProductsCharacteristic.InventoryMinimumLevel,
	|	ReorderPointsProductsCharacteristic.InventoryMaximumLevel,
	|	ReorderPointsProductsCharacteristic.Vendor
	|FROM
	|	ReorderPointsProductsCharacteristic AS ReorderPointsProductsCharacteristic
	|
	|UNION ALL
	|
	|SELECT
	|	ReorderPointsProducts.Products,
	|	ReorderPointsProducts.Characteristic,
	|	ReorderPointsProducts.InventoryMinimumLevel,
	|	ReorderPointsProducts.InventoryMaximumLevel,
	|	ReorderPointsProducts.Vendor
	|FROM
	|	ReorderPointsProducts AS ReorderPointsProducts
	|		LEFT JOIN ReorderPointsProductsCharacteristic AS ReorderPointsProductsCharacteristic
	|		ON ReorderPointsProducts.Products = ReorderPointsProductsCharacteristic.Products
	|			AND ReorderPointsProducts.Characteristic = ReorderPointsProductsCharacteristic.Characteristic
	|WHERE
	|	ReorderPointsProductsCharacteristic.Products IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	LineNeedsInventory.Period AS Period,
	|	LineNeedsInventory.Products AS Products,
	|	LineNeedsInventory.ReplenishmentMethod AS ReplenishmentMethod,
	|	LineNeedsInventory.Vendor AS Vendor,
	|	LineNeedsInventory.Characteristic AS Characteristic,
	|	LineNeedsInventory.Order AS Order,
	|	LineNeedsInventory.MovementType AS MovementType,
	|	SUM(LineNeedsInventory.OrderBalance) AS OrderBalance,
	|	SUM(LineNeedsInventory.MinInventory) AS MinInventory,
	|	SUM(LineNeedsInventory.MaxInventory) AS MaxInventory,
	|	SUM(LineNeedsInventory.AvailableBalance) AS AvailableBalance,
	|	SUM(LineNeedsInventory.Receipt) AS Receipt,
	|	SUM(LineNeedsInventory.ReceiptOverdue) AS ReceiptOverdue,
	|	SUM(LineNeedsInventory.Demand) AS Demand,
	|	SUM(LineNeedsInventory.NeedOverdue) AS NeedOverdue,
	|	SUM(LineNeedsInventory.ClosingBalance) AS ClosingBalance,
	|	SUM(LineNeedsInventory.Overdue) AS Overdue,
	|	SUM(LineNeedsInventory.Deficit) AS Deficit,
	|	LineNeedsInventory.SalesOrder AS SalesOrder
	|INTO TemporaryTableInventoryNeedsSchedule
	|FROM
	|	(SELECT
	|		&StartDate AS Period,
	|		InventoryBalances.Products AS Products,
	|		CatalogProducts.ReplenishmentMethod AS ReplenishmentMethod,
	|		CASE
	|			WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|				THEN VALUE(Catalog.Counterparties.EmptyRef)
	|			ELSE InventoryBalances.Products.Vendor
	|		END AS Vendor,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN InventoryBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		UNDEFINED AS Order,
	|		UNDEFINED AS MovementType,
	|		UNDEFINED AS SalesOrder,
	|		0 AS OrderBalance,
	|		InventoryBalances.QuantityBalance AS AvailableBalance,
	|		0 AS Receipt,
	|		0 AS ReceiptOverdue,
	|		0 AS Demand,
	|		0 AS NeedOverdue,
	|		0 AS MinInventory,
	|		0 AS MaxInventory,
	|		0 AS ClosingBalance,
	|		0 AS Overdue,
	|		0 AS Deficit
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&DateBalance,
	|				Company = &Company
	|					AND VALUETYPE(StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|					AND InventoryAccountType = VALUE(Enum.InventoryAccountTypes.InventoryOnHand) {(Products).* AS Products, (Characteristic).* AS Characteristic, (StructuralUnit).* AS Warehouse}) AS InventoryBalances
	|			INNER JOIN Catalog.Products AS CatalogProducts
	|			ON InventoryBalances.Products = CatalogProducts.Ref
	|				AND (CatalogProducts.ReplenishmentMethod IN (&ReplenishmentMethods))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		&StartDate,
	|		ReorderPointSettings.Products,
	|		CatalogProducts.ReplenishmentMethod,
	|		ReorderPointSettings.Vendor,
	|		ReorderPointSettings.Characteristic,
	|		UNDEFINED,
	|		UNDEFINED,
	|		UNDEFINED,
	|		0,
	|		0,
	|		0,
	|		0,
	|		0,
	|		0,
	|		ReorderPointSettings.InventoryMinimumLevel,
	|		ReorderPointSettings.InventoryMaximumLevel,
	|		0,
	|		0,
	|		0
	|	FROM
	|		ReorderPointSettingsTable AS ReorderPointSettings
	|			INNER JOIN Catalog.Products AS CatalogProducts
	|			ON ReorderPointSettings.Products = CatalogProducts.Ref
	|				AND (CatalogProducts.ReplenishmentMethod IN (&ReplenishmentMethods))
	|	{WHERE
	|		ReorderPointSettings.Products.* AS Products,
	|		ReorderPointSettings.Characteristic.* AS Characteristic}
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN InventoryFlowCalendar.Period < &StartDate
	|					OR InventoryFlowCalendar.Period > &EndDate
	|					OR InventoryFlowCalendar.Period IS NULL
	|				THEN &StartDate
	|			ELSE InventoryFlowCalendar.Period
	|		END,
	|		OrdersBalance.Products,
	|		OrdersBalance.ReplenishmentMethod,
	|		OrdersBalance.Vendor,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN OrdersBalance.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		OrdersBalance.Order,
	|		OrdersBalance.MovementType,
	|		OrdersBalance.SalesOrder,
	|		CASE
	|			WHEN InventoryFlowCalendar.Period > &EndDate
	|				THEN -InventoryFlowCalendar.Quantity
	|			ELSE OrdersBalance.QuantityBalance
	|		END,
	|		0,
	|		SUM(CASE
	|				WHEN InventoryFlowCalendar.MovementType = VALUE(Enum.InventoryMovementTypes.Receipt)
	|						AND InventoryFlowCalendar.Period <= &EndDate
	|						AND InventoryFlowCalendar.Period >= &StartDate
	|					THEN InventoryFlowCalendar.Quantity
	|				ELSE 0
	|			END),
	|		0,
	|		SUM(CASE
	|				WHEN InventoryFlowCalendar.MovementType = VALUE(Enum.InventoryMovementTypes.Shipment)
	|						AND InventoryFlowCalendar.Period <= &EndDate
	|						AND InventoryFlowCalendar.Period >= &StartDate
	|					THEN InventoryFlowCalendar.Quantity
	|				ELSE 0
	|			END),
	|		0,
	|		0,
	|		0,
	|		0,
	|		0,
	|		0
	|	FROM
	|		TemporaryTableOrdersBalance AS OrdersBalance
	|			LEFT JOIN AccumulationRegister.InventoryFlowCalendar AS InventoryFlowCalendar
	|			ON OrdersBalance.Company = InventoryFlowCalendar.Company
	|				AND OrdersBalance.Products = InventoryFlowCalendar.Products
	|				AND OrdersBalance.Characteristic = InventoryFlowCalendar.Characteristic
	|				AND OrdersBalance.MovementType = InventoryFlowCalendar.MovementType
	|				AND (InventoryFlowCalendar.ProductionDocument <> UNDEFINED
	|						AND OrdersBalance.Order = InventoryFlowCalendar.ProductionDocument
	|					OR InventoryFlowCalendar.ProductionDocument = UNDEFINED
	|						AND OrdersBalance.Order = InventoryFlowCalendar.Order)
	|	{WHERE
	|		InventoryFlowCalendar.Products.* AS Products,
	|		InventoryFlowCalendar.Characteristic.* AS Characteristic}
	|	
	|	GROUP BY
	|		CASE
	|			WHEN InventoryFlowCalendar.Period < &StartDate
	|					OR InventoryFlowCalendar.Period > &EndDate
	|					OR InventoryFlowCalendar.Period IS NULL
	|				THEN &StartDate
	|			ELSE InventoryFlowCalendar.Period
	|		END,
	|		OrdersBalance.Products,
	|		OrdersBalance.ReplenishmentMethod,
	|		OrdersBalance.Vendor,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN OrdersBalance.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		OrdersBalance.Order,
	|		OrdersBalance.MovementType,
	|		CASE
	|			WHEN InventoryFlowCalendar.Period > &EndDate
	|				THEN -InventoryFlowCalendar.Quantity
	|			ELSE OrdersBalance.QuantityBalance
	|		END,
	|		OrdersBalance.SalesOrder) AS LineNeedsInventory
	|
	|GROUP BY
	|	LineNeedsInventory.Period,
	|	LineNeedsInventory.Products,
	|	LineNeedsInventory.ReplenishmentMethod,
	|	LineNeedsInventory.Vendor,
	|	LineNeedsInventory.Characteristic,
	|	LineNeedsInventory.Order,
	|	LineNeedsInventory.MovementType,
	|	LineNeedsInventory.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TemporaryTableInventoryNeedsSchedule.Period AS Period,
	|	TemporaryTableInventoryNeedsSchedule.Products AS Products,
	|	CASE
	|		WHEN TemporaryTableInventoryNeedsSchedule.Vendor = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN CounterpartyPricesSliceLast.Counterparty
	|		ELSE TemporaryTableInventoryNeedsSchedule.Vendor
	|	END AS Vendor,
	|	TemporaryTableInventoryNeedsSchedule.Characteristic AS Characteristic,
	|	TemporaryTableInventoryNeedsSchedule.Order AS Order,
	|	TemporaryTableInventoryNeedsSchedule.MovementType AS MovementType,
	|	TemporaryTableInventoryNeedsSchedule.SalesOrder AS SalesOrder,
	|	TemporaryTableInventoryNeedsSchedule.OrderBalance AS OrderBalance,
	|	TemporaryTableInventoryNeedsSchedule.MinInventory AS MinInventory,
	|	TemporaryTableInventoryNeedsSchedule.MaxInventory AS MaxInventory,
	|	TemporaryTableInventoryNeedsSchedule.AvailableBalance AS AvailableBalance,
	|	TemporaryTableInventoryNeedsSchedule.Receipt AS Receipt,
	|	TemporaryTableInventoryNeedsSchedule.ReceiptOverdue AS ReceiptOverdue,
	|	TemporaryTableInventoryNeedsSchedule.Demand AS Demand,
	|	TemporaryTableInventoryNeedsSchedule.NeedOverdue AS NeedOverdue,
	|	TemporaryTableInventoryNeedsSchedule.ClosingBalance AS ClosingBalance,
	|	TemporaryTableInventoryNeedsSchedule.Overdue AS Overdue,
	|	TemporaryTableInventoryNeedsSchedule.Deficit AS Deficit
	|FROM
	|	TemporaryTableInventoryNeedsSchedule AS TemporaryTableInventoryNeedsSchedule
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&StartDate,
	|				Counterparty = &Counterparty
	|					AND &Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)) AS CounterpartyPricesSliceLast
	|		ON TemporaryTableInventoryNeedsSchedule.Products = CounterpartyPricesSliceLast.Products
	|			AND TemporaryTableInventoryNeedsSchedule.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|			AND (CounterpartyPricesSliceLast.Actuality)
	|WHERE
	|	(TemporaryTableInventoryNeedsSchedule.Vendor = &Counterparty
	|			OR CounterpartyPricesSliceLast.Counterparty = &Counterparty
	|			OR &Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|			OR TemporaryTableInventoryNeedsSchedule.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production))
	|
	|ORDER BY
	|	Products,
	|	Characteristic,
	|	Period,
	|	Order";
	
	Return QueryText;
	
EndFunction

// end Drive.FullVersion

&AtServerNoContext
Function TradeVersionQueryText()
	
	QueryText = 
	"SELECT ALLOWED
	|	OrdersBalance.MovementType AS MovementType,
	|	OrdersBalance.Company AS Company,
	|	OrdersBalance.Products AS Products,
	|	CatalogProducts.ReplenishmentMethod AS ReplenishmentMethod,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Processing)
	|				AND &CanReceiveSubcontractingServices
	|			THEN CatalogProducts.Subcontractor
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Order AS Order,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance,
	|	OrdersBalance.SalesOrder AS SalesOrder
	|INTO TemporaryTableOrdersBalance
	|FROM
	|	(SELECT
	|		VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|		SalesOrdersBalances.Company AS Company,
	|		SalesOrdersBalances.Products AS Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN SalesOrdersBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		SalesOrdersBalances.SalesOrder AS Order,
	|		SalesOrdersBalances.QuantityBalance AS QuantityBalance,
	|		SalesOrdersBalances.SalesOrder AS SalesOrder
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS SalesOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Shipment),
	|		WorkOrdersBalances.Company,
	|		WorkOrdersBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN WorkOrdersBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		WorkOrdersBalances.WorkOrder,
	|		WorkOrdersBalances.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.WorkOrders.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS WorkOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryDemandBalances.MovementType,
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN InventoryDemandBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		CASE
	|			WHEN InventoryDemandBalances.ProductionDocument <> UNDEFINED
	|					AND InventoryDemandBalances.ProductionDocument <> VALUE(Document.KitOrder.EmptyRef)
	|				THEN InventoryDemandBalances.ProductionDocument
	|			ELSE InventoryDemandBalances.SalesOrder
	|		END,
	|		InventoryDemandBalances.QuantityBalance,
	|		InventoryDemandBalances.SalesOrder
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(&EndDate, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS InventoryDemandBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Receipt),
	|		PurchaseOrdersBalances.Company,
	|		PurchaseOrdersBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN PurchaseOrdersBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		PurchaseOrdersBalances.PurchaseOrder,
	|		PurchaseOrdersBalances.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.PurchaseOrders.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS PurchaseOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Receipt),
	|		GoodsInvoicedNotReceivedBalance.Company,
	|		GoodsInvoicedNotReceivedBalance.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN GoodsInvoicedNotReceivedBalance.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		GoodsInvoicedNotReceivedBalance.PurchaseOrder,
	|		GoodsInvoicedNotReceivedBalance.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotReceived.Balance(&DateBalance, Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS GoodsInvoicedNotReceivedBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VALUE(Enum.InventoryMovementTypes.Receipt),
	|		SubcontractorOrdersIssuedBalances.Company,
	|		SubcontractorOrdersIssuedBalances.Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN SubcontractorOrdersIssuedBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		SubcontractorOrdersIssuedBalances.SubcontractorOrder,
	|		SubcontractorOrdersIssuedBalances.QuantityBalance,
	|		VALUE(Document.SalesOrder.EmptyRef)
	|	FROM
	|		AccumulationRegister.SubcontractorOrdersIssued.Balance(
	|				&DateBalance,
	|				Company = &Company {(Products).* AS Products, (Characteristic).* AS Characteristic}) AS SubcontractorOrdersIssuedBalances) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON OrdersBalance.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|			AND (CatalogProducts.ReplenishmentMethod IN (&ReplenishmentMethods))
	|
	|GROUP BY
	|	OrdersBalance.Company,
	|	OrdersBalance.Products,
	|	CatalogProducts.ReplenishmentMethod,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Processing)
	|				AND &CanReceiveSubcontractingServices
	|			THEN CatalogProducts.Subcontractor
	|		ELSE CatalogProducts.Vendor
	|	END,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.MovementType,
	|	OrdersBalance.Order,
	|	OrdersBalance.SalesOrder
	|
	|INDEX BY
	|	Company,
	|	Products,
	|	Characteristic,
	|	Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReorderPointSettings.Products AS Products,
	|	ReorderPointSettings.Characteristic AS Characteristic,
	|	ReorderPointSettings.InventoryMinimumLevel AS InventoryMinimumLevel,
	|	ReorderPointSettings.InventoryMaximumLevel AS InventoryMaximumLevel,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor
	|INTO ReorderPointsProductsCharacteristic
	|FROM
	|	InformationRegister.ReorderPointSettings AS ReorderPointSettings
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ReorderPointSettings.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.UseCharacteristics)
	|WHERE
	|	ReorderPointSettings.Company = &Company
	|	AND &UseCharacteristics
	|	AND ReorderPointSettings.Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReorderPointSettings.Products AS Products,
	|	ProductsCharacteristics.Ref AS Characteristic,
	|	ReorderPointSettings.InventoryMinimumLevel AS InventoryMinimumLevel,
	|	ReorderPointSettings.InventoryMaximumLevel AS InventoryMaximumLevel,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor
	|INTO ReorderPointsProducts
	|FROM
	|	InformationRegister.ReorderPointSettings AS ReorderPointSettings
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ReorderPointSettings.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.UseCharacteristics)
	|		INNER JOIN Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|		ON ReorderPointSettings.Products = ProductsCharacteristics.Owner
	|WHERE
	|	ReorderPointSettings.Company = &Company
	|	AND &UseCharacteristics
	|	AND ReorderPointSettings.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReorderPointSettings.Products AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	ReorderPointSettings.InventoryMinimumLevel AS InventoryMinimumLevel,
	|	ReorderPointSettings.InventoryMaximumLevel AS InventoryMaximumLevel,
	|	CASE
	|		WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		ELSE CatalogProducts.Vendor
	|	END AS Vendor
	|INTO ReorderPointSettingsTable
	|FROM
	|	InformationRegister.ReorderPointSettings AS ReorderPointSettings
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ReorderPointSettings.Products = CatalogProducts.Ref
	|WHERE
	|	ReorderPointSettings.Company = &Company
	|	AND (NOT &UseCharacteristics
	|			OR NOT CatalogProducts.UseCharacteristics)
	|
	|UNION ALL
	|
	|SELECT
	|	ReorderPointsProductsCharacteristic.Products,
	|	ReorderPointsProductsCharacteristic.Characteristic,
	|	ReorderPointsProductsCharacteristic.InventoryMinimumLevel,
	|	ReorderPointsProductsCharacteristic.InventoryMaximumLevel,
	|	ReorderPointsProductsCharacteristic.Vendor
	|FROM
	|	ReorderPointsProductsCharacteristic AS ReorderPointsProductsCharacteristic
	|
	|UNION ALL
	|
	|SELECT
	|	ReorderPointsProducts.Products,
	|	ReorderPointsProducts.Characteristic,
	|	ReorderPointsProducts.InventoryMinimumLevel,
	|	ReorderPointsProducts.InventoryMaximumLevel,
	|	ReorderPointsProducts.Vendor
	|FROM
	|	ReorderPointsProducts AS ReorderPointsProducts
	|		LEFT JOIN ReorderPointsProductsCharacteristic AS ReorderPointsProductsCharacteristic
	|		ON ReorderPointsProducts.Products = ReorderPointsProductsCharacteristic.Products
	|			AND ReorderPointsProducts.Characteristic = ReorderPointsProductsCharacteristic.Characteristic
	|WHERE
	|	ReorderPointsProductsCharacteristic.Products IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	LineNeedsInventory.Period AS Period,
	|	LineNeedsInventory.Products AS Products,
	|	LineNeedsInventory.ReplenishmentMethod AS ReplenishmentMethod,
	|	LineNeedsInventory.Vendor AS Vendor,
	|	LineNeedsInventory.Characteristic AS Characteristic,
	|	LineNeedsInventory.Order AS Order,
	|	LineNeedsInventory.MovementType AS MovementType,
	|	SUM(LineNeedsInventory.OrderBalance) AS OrderBalance,
	|	SUM(LineNeedsInventory.MinInventory) AS MinInventory,
	|	SUM(LineNeedsInventory.MaxInventory) AS MaxInventory,
	|	SUM(LineNeedsInventory.AvailableBalance) AS AvailableBalance,
	|	SUM(LineNeedsInventory.Receipt) AS Receipt,
	|	SUM(LineNeedsInventory.ReceiptOverdue) AS ReceiptOverdue,
	|	SUM(LineNeedsInventory.Demand) AS Demand,
	|	SUM(LineNeedsInventory.NeedOverdue) AS NeedOverdue,
	|	SUM(LineNeedsInventory.ClosingBalance) AS ClosingBalance,
	|	SUM(LineNeedsInventory.Overdue) AS Overdue,
	|	SUM(LineNeedsInventory.Deficit) AS Deficit,
	|	LineNeedsInventory.SalesOrder AS SalesOrder
	|INTO TemporaryTableInventoryNeedsSchedule
	|FROM
	|	(SELECT
	|		&StartDate AS Period,
	|		InventoryBalances.Products AS Products,
	|		CatalogProducts.ReplenishmentMethod AS ReplenishmentMethod,
	|		CASE
	|			WHEN CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|				THEN VALUE(Catalog.Counterparties.EmptyRef)
	|			ELSE InventoryBalances.Products.Vendor
	|		END AS Vendor,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN InventoryBalances.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		UNDEFINED AS Order,
	|		UNDEFINED AS MovementType,
	|		UNDEFINED AS SalesOrder,
	|		0 AS OrderBalance,
	|		InventoryBalances.QuantityBalance AS AvailableBalance,
	|		0 AS Receipt,
	|		0 AS ReceiptOverdue,
	|		0 AS Demand,
	|		0 AS NeedOverdue,
	|		0 AS MinInventory,
	|		0 AS MaxInventory,
	|		0 AS ClosingBalance,
	|		0 AS Overdue,
	|		0 AS Deficit
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&DateBalance,
	|				Company = &Company
	|					AND VALUETYPE(StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|					AND InventoryAccountType = VALUE(Enum.InventoryAccountTypes.InventoryOnHand) {(Products).* AS Products, (Characteristic).* AS Characteristic, (StructuralUnit).* AS Warehouse}) AS InventoryBalances
	|			INNER JOIN Catalog.Products AS CatalogProducts
	|			ON InventoryBalances.Products = CatalogProducts.Ref
	|				AND (CatalogProducts.ReplenishmentMethod IN (&ReplenishmentMethods))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		&StartDate,
	|		ReorderPointSettings.Products,
	|		CatalogProducts.ReplenishmentMethod,
	|		ReorderPointSettings.Vendor,
	|		ReorderPointSettings.Characteristic,
	|		UNDEFINED,
	|		UNDEFINED,
	|		UNDEFINED,
	|		0,
	|		0,
	|		0,
	|		0,
	|		0,
	|		0,
	|		ReorderPointSettings.InventoryMinimumLevel,
	|		ReorderPointSettings.InventoryMaximumLevel,
	|		0,
	|		0,
	|		0
	|	FROM
	|		ReorderPointSettingsTable AS ReorderPointSettings
	|			INNER JOIN Catalog.Products AS CatalogProducts
	|			ON ReorderPointSettings.Products = CatalogProducts.Ref
	|				AND (CatalogProducts.ReplenishmentMethod IN (&ReplenishmentMethods))
	|	{WHERE
	|		ReorderPointSettings.Products.* AS Products,
	|		ReorderPointSettings.Characteristic.* AS Characteristic}
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN InventoryFlowCalendar.Period < &StartDate
	|					OR InventoryFlowCalendar.Period > &EndDate
	|					OR InventoryFlowCalendar.Period IS NULL
	|				THEN &StartDate
	|			ELSE InventoryFlowCalendar.Period
	|		END,
	|		OrdersBalance.Products,
	|		OrdersBalance.ReplenishmentMethod,
	|		OrdersBalance.Vendor,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN OrdersBalance.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		OrdersBalance.Order,
	|		OrdersBalance.MovementType,
	|		OrdersBalance.SalesOrder,
	|		CASE
	|			WHEN InventoryFlowCalendar.Period > &EndDate
	|				THEN -InventoryFlowCalendar.Quantity
	|			ELSE OrdersBalance.QuantityBalance
	|		END,
	|		0,
	|		SUM(CASE
	|				WHEN InventoryFlowCalendar.MovementType = VALUE(Enum.InventoryMovementTypes.Receipt)
	|						AND InventoryFlowCalendar.Period <= &EndDate
	|						AND InventoryFlowCalendar.Period >= &StartDate
	|					THEN InventoryFlowCalendar.Quantity
	|				ELSE 0
	|			END),
	|		0,
	|		SUM(CASE
	|				WHEN InventoryFlowCalendar.MovementType = VALUE(Enum.InventoryMovementTypes.Shipment)
	|						AND InventoryFlowCalendar.Period <= &EndDate
	|						AND InventoryFlowCalendar.Period >= &StartDate
	|					THEN InventoryFlowCalendar.Quantity
	|				ELSE 0
	|			END),
	|		0,
	|		0,
	|		0,
	|		0,
	|		0,
	|		0
	|	FROM
	|		TemporaryTableOrdersBalance AS OrdersBalance
	|			LEFT JOIN AccumulationRegister.InventoryFlowCalendar AS InventoryFlowCalendar
	|			ON OrdersBalance.Company = InventoryFlowCalendar.Company
	|				AND OrdersBalance.Products = InventoryFlowCalendar.Products
	|				AND OrdersBalance.Characteristic = InventoryFlowCalendar.Characteristic
	|				AND OrdersBalance.MovementType = InventoryFlowCalendar.MovementType
	|				AND (InventoryFlowCalendar.ProductionDocument <> UNDEFINED
	|						AND InventoryFlowCalendar.ProductionDocument <> VALUE(Document.KitOrder.EmptyRef)
	|						AND OrdersBalance.Order = InventoryFlowCalendar.ProductionDocument
	|					OR (InventoryFlowCalendar.ProductionDocument = UNDEFINED
	|						OR InventoryFlowCalendar.ProductionDocument = VALUE(Document.KitOrder.EmptyRef))
	|						AND OrdersBalance.Order = InventoryFlowCalendar.Order)
	|	{WHERE
	|		InventoryFlowCalendar.Products.* AS Products,
	|		InventoryFlowCalendar.Characteristic.* AS Characteristic}
	|	
	|	GROUP BY
	|		CASE
	|			WHEN InventoryFlowCalendar.Period < &StartDate
	|					OR InventoryFlowCalendar.Period > &EndDate
	|					OR InventoryFlowCalendar.Period IS NULL
	|				THEN &StartDate
	|			ELSE InventoryFlowCalendar.Period
	|		END,
	|		OrdersBalance.Products,
	|		OrdersBalance.ReplenishmentMethod,
	|		OrdersBalance.Vendor,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN OrdersBalance.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END,
	|		OrdersBalance.Order,
	|		OrdersBalance.MovementType,
	|		CASE
	|			WHEN InventoryFlowCalendar.Period > &EndDate
	|				THEN -InventoryFlowCalendar.Quantity
	|			ELSE OrdersBalance.QuantityBalance
	|		END,
	|		OrdersBalance.SalesOrder) AS LineNeedsInventory
	|
	|GROUP BY
	|	LineNeedsInventory.Period,
	|	LineNeedsInventory.Products,
	|	LineNeedsInventory.ReplenishmentMethod,
	|	LineNeedsInventory.Vendor,
	|	LineNeedsInventory.Characteristic,
	|	LineNeedsInventory.Order,
	|	LineNeedsInventory.MovementType,
	|	LineNeedsInventory.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TemporaryTableInventoryNeedsSchedule.Period AS Period,
	|	TemporaryTableInventoryNeedsSchedule.Products AS Products,
	|	CASE
	|		WHEN TemporaryTableInventoryNeedsSchedule.Vendor = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN CounterpartyPricesSliceLast.Counterparty
	|		ELSE TemporaryTableInventoryNeedsSchedule.Vendor
	|	END AS Vendor,
	|	TemporaryTableInventoryNeedsSchedule.Characteristic AS Characteristic,
	|	TemporaryTableInventoryNeedsSchedule.Order AS Order,
	|	TemporaryTableInventoryNeedsSchedule.MovementType AS MovementType,
	|	TemporaryTableInventoryNeedsSchedule.SalesOrder AS SalesOrder,
	|	TemporaryTableInventoryNeedsSchedule.OrderBalance AS OrderBalance,
	|	TemporaryTableInventoryNeedsSchedule.MinInventory AS MinInventory,
	|	TemporaryTableInventoryNeedsSchedule.MaxInventory AS MaxInventory,
	|	TemporaryTableInventoryNeedsSchedule.AvailableBalance AS AvailableBalance,
	|	TemporaryTableInventoryNeedsSchedule.Receipt AS Receipt,
	|	TemporaryTableInventoryNeedsSchedule.ReceiptOverdue AS ReceiptOverdue,
	|	TemporaryTableInventoryNeedsSchedule.Demand AS Demand,
	|	TemporaryTableInventoryNeedsSchedule.NeedOverdue AS NeedOverdue,
	|	TemporaryTableInventoryNeedsSchedule.ClosingBalance AS ClosingBalance,
	|	TemporaryTableInventoryNeedsSchedule.Overdue AS Overdue,
	|	TemporaryTableInventoryNeedsSchedule.Deficit AS Deficit
	|FROM
	|	TemporaryTableInventoryNeedsSchedule AS TemporaryTableInventoryNeedsSchedule
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&StartDate,
	|				Counterparty = &Counterparty
	|					AND &Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)) AS CounterpartyPricesSliceLast
	|		ON TemporaryTableInventoryNeedsSchedule.Products = CounterpartyPricesSliceLast.Products
	|			AND TemporaryTableInventoryNeedsSchedule.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|			AND (CounterpartyPricesSliceLast.Actuality)
	|WHERE
	|	(TemporaryTableInventoryNeedsSchedule.Vendor = &Counterparty
	|			OR CounterpartyPricesSliceLast.Counterparty = &Counterparty
	|			OR &Counterparty = VALUE(Catalog.Counterparties.EmptyRef))
	|
	|ORDER BY
	|	Products,
	|	Characteristic,
	|	Period,
	|	Order";
	
	Return QueryText;
	
EndFunction

&AtServerNoContext
Function GetOrderInProgressStatus(CatalogName)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	OrderStatuses.Ref AS Ref
	|FROM
	|	&Catalog AS OrderStatuses
	|WHERE
	|	OrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
	
	Query.Text = StrReplace(Query.Text, "&Catalog", "Catalog." + CatalogName + "Statuses");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Execute("Return Catalogs." + CatalogName + "Statuses.EmptyRef();");
	EndIf;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance(BeginOfPeriod, EndOfPeriod)
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	For Each Item In ListOfItemsForDeletion Do
		ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	// Negative in the deficit is highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryDeficit");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Deficit");
	FilterItem.ComparisonType = DataCompositionComparisonType.Less;
	FilterItem.RightValue = 0;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	
	// Negative overdue is highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Overdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Less;
	FilterItem.RightValue = 0;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	
	// Decryption overdue is displayed in the background color.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Overdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
	FilterItem.RightValue = 0;
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Products");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = NStr("en = 'Inbound quantity'; ru = 'Входящее количество';pl = 'Ilość przychodząca';es_ES = 'Cantidad entrante';es_CO = 'Cantidad entrante';tr = 'Gelen miktar';it = 'Quantità in entrata';de = 'Eingehende Menge'");
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.LightGray);
	
	CurrentPeriod = BeginOfPeriod;
	
	While BegOfDay(CurrentPeriod) <= BegOfDay(EndOfPeriod) Do
		
		// Negative in the period is highlighted.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Period" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Less;
		FilterItem.RightValue = 0;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
		
		// Decryption of the period is displayed in the background color.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Period" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
		FilterItem.RightValue = 0;
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Products");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = NStr("en = 'Inbound quantity'; ru = 'Входящее количество';pl = 'Ilość przychodząca';es_ES = 'Cantidad entrante';es_CO = 'Cantidad entrante';tr = 'Gelen miktar';it = 'Quantità in entrata';de = 'Eingehende Menge'");
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.LightGray);
		
		CurrentPeriod = CurrentPeriod + 86400;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure GenerateDemandPeriod()
	
	CalendarDateBegin = BegOfDay(BegOfDay(CommonClient.SessionDate()));
	CalendarDateEnd = EndOfDay(EndOfPeriod);
	
	If Month(CalendarDateBegin) = Month(CalendarDateEnd) Then
		
		DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
		WeekDayOfScheduleBegin = DriveClient.GetPresentationOfWeekDay(CalendarDateBegin);
		DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
		WeekDayOfScheduleEnd = DriveClient.GetPresentationOfWeekDay(CalendarDateEnd);
		
		MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
		YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
		
		PeriodPresentation = WeekDayOfScheduleBegin
			+ " "
			+ DayOfScheduleBegin
			+ " - "
			+ WeekDayOfScheduleEnd
			+ " "
			+ DayOfScheduleEnd
			+ " "
			+ MonthOfSchedule
			+ ", "
			+ YearOfSchedule;
		
	Else
		
		DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
		WeekDayOfScheduleBegin = DriveClient.GetPresentationOfWeekDay(CalendarDateBegin);
		MonthOfScheduleBegin = Format(CalendarDateBegin, "DF=MMM");
		DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
		WeekDayOfScheduleEnd = DriveClient.GetPresentationOfWeekDay(CalendarDateEnd);
		MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
		
		If Year(CalendarDateBegin) = Year(CalendarDateEnd) Then
			YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
			PeriodPresentation = WeekDayOfScheduleBegin
				+ " "
				+ DayOfScheduleBegin
				+ " "
				+ MonthOfScheduleBegin
				+ " - "
				+ WeekDayOfScheduleEnd
				+ " "
				+ DayOfScheduleEnd
				+ " "
				+ MonthOfScheduleEnd
				+ ", "
				+ YearOfSchedule;
		Else
			YearOfScheduleBegin = Format(Year(CalendarDateBegin), "NG=0");
			YearOfScheduleEnd = Format(Year(CalendarDateEnd), "NG=0");
			PeriodPresentation = WeekDayOfScheduleBegin
				+ " "
				+ DayOfScheduleBegin
				+ " "
				+ MonthOfScheduleBegin
				+ " "
				+ YearOfScheduleBegin
				+ " - "
				+ WeekDayOfScheduleEnd
				+ " "
				+ DayOfScheduleEnd
				+ " "
				+ MonthOfScheduleEnd
				+ " "
				+ YearOfScheduleEnd;
			
		EndIf;
		
	EndIf;
	
	ClearTables();
	
EndProcedure

&AtServer
Procedure UpdateStateOrdersAtServer()
	
	RowsToDelete = New Array;
	
	For Each OrderRow In Orders Do
		
		CurrentOrder = OrderRow.Order;
		
		If Common.RefExists(CurrentOrder) Then
			If CurrentOrder.Posted Then
				OrderRow.DefaultPicture = 1;
			ElsIf CurrentOrder.DeletionMark Then
				OrderRow.DefaultPicture = 3;
			Else
				OrderRow.DefaultPicture = 0;
			EndIf;
		Else
			RowsToDelete.Add(OrderRow);
		EndIf;
		
	EndDo;
	
	For Each Row In RowsToDelete Do
		Orders.Delete(Row);
	EndDo;
	
EndProcedure

&AtServer
Procedure ClearTables()
	
	Inventory.GetItems().Clear();
	Recommendations.GetItems().Clear();
	Modified = False;
	
	AddressInventory = PutToTempStorage(FormAttributeToValue("Inventory"), UUID);
	
EndProcedure

&AtClient
Procedure UncheckRecommendations()
	
	For Each ProductsItem In Recommendations.GetItems() Do
		
		ProductsItem.Selected = False;
		ProductsItem.DemandClosed = False;
		
		For Each ReplenishmentMethodItem In ProductsItem.GetItems() Do
			ReplenishmentMethodItem.Selected = False;
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckRecommendations()
	
	For Each ProductsItem In Recommendations.GetItems() Do
		
		For Each ReplenishmentMethodItem In ProductsItem.GetItems() Do
			
			If Not ReplenishmentMethodItem.ReceiptDateExpired
				And ReplenishmentMethodItem.ReplenishmentMethodPrecision = 1 Then
				
				ProductsItem.ReceiptDateExpired = False;
				ProductsItem.DemandClosed = True;
				
				If Not ProductsItem.Selected Then
					
					ReplenishmentMethodItem.Selected = True;
					ProductsItem.Selected = True;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function PostDocumentAtServer(DocumentsForProcessing)
	
	ProcessedDocuments = New Map;
	
	For Each DocKeyAndValue In DocumentsForProcessing Do
		
		DocObject = DocKeyAndValue.Value.GetObject();
		
		If Not DocObject.DeletionMark Then
			
			If DocObject.CheckFilling() Then
				
				Try
					
					DocObject.Write(DocumentWriteMode.Posting);
					ProcessedDocuments.Insert(DocKeyAndValue.Key, 1);
					
				Except
					
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot post the %1 document.'; ru = 'Не удалось провести документ: %1.';pl = 'Nie można zatwierdzić dokumentu %1.';es_ES = 'No se puede enviar el %1 documento.';es_CO = 'No se puede enviar el %1 documento.';tr = '%1 belgesi kaydedilemiyor.';it = 'Impossibile pubblicare il documento %1.';de = 'Das %1 Dokument kann nicht gebucht werden.'"),
						String(DocObject.Ref));
					
					CommonClientServer.MessageToUser(MessageText);
					
				EndTry;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return ProcessedDocuments;
	
EndFunction

&AtServerNoContext
Function UndoPostingDocumentAtServer(DocumentsForProcessing)
	
	ProcessedDocuments = New Map;
	
	For Each DocKeyAndValue In DocumentsForProcessing Do
		
		DocObject = DocKeyAndValue.Value.GetObject();
		
		If Not DocObject.DeletionMark And DocObject.Posted Then
			
			Try
				
				DocObject.Write(DocumentWriteMode.UndoPosting);
				ProcessedDocuments.Insert(DocKeyAndValue.Key, 0);
				
			Except
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot undo posting the %1 document.'; ru = 'Не удалось отменить проведение документа %1.';pl = 'Nie można cofnąć zatwierdzenia %1 dokumentu.';es_ES = 'No se puede anular el envío del %1 documento.';es_CO = 'No se puede anular el envío del %1 documento.';tr = '%1 belgesinin kaydedilmesi geri alınamıyor.';it = 'Impossibile annullare la pubblicazione del documento %1.';de = 'Kann die Buchung des %1 Dokumentes nicht rückgängig machen.'"),
					String(DocObject.Ref));
				
				CommonClientServer.MessageToUser(MessageText);
				
			EndTry;
			
		EndIf;
		
	EndDo;
	
	Return ProcessedDocuments;
	
EndFunction

&AtServerNoContext
Function MarkToDeleteDocumentAtServer(DocumentsForProcessing)
	
	ProcessedDocuments = New Map;
	
	For Each DocKeyAndValue In DocumentsForProcessing Do
		
		DocObject = DocKeyAndValue.Value.GetObject();
		
		Try
			
			DocObject.SetDeletionMark(Not DocObject.DeletionMark);
			
			If DocObject.DeletionMark Then
				ProcessedDocuments.Insert(DocKeyAndValue.Key, 3);
			Else
				ProcessedDocuments.Insert(DocKeyAndValue.Key, 0);
			EndIf;
			
		Except
			
			If DocObject.DeletionMark Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot unmark for deletion the %1 document.'; ru = 'Не удалось снять пометку на удаление документа %1.';pl = 'Nie można usunąć zaznaczenie do usunięcia dokumentu %1.';es_ES = 'No se puede desmarcar para borrar el %1 documento.';es_CO = 'No se puede desmarcar para borrar el %1 documento.';tr = '%1 belgesinin silme işareti kaldırılamıyor.';it = 'Impossibile deselezionare il documento %1 per la cancellazione.';de = 'Kann Markierung des Dokumentes %1 zum Löschen nicht deaktivieren.'"),
					String(DocObject.Ref));
			Else
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot mark for deletion the %1 document.'; ru = 'Не удалось пометить документ %1 на удаление.';pl = 'Nie można zaznaczyć do usunięcia dokumentu %1.';es_ES = 'No se puede marcar para borrar el %1 documento.';es_CO = 'No se puede marcar para borrar el %1 documento.';tr = '%1 belgesi silme için işaretlenemiyor.';it = 'Impossibile contrassegnare il documento %1 per la cancellazione.';de = 'Kann das Dokument %1 zum Löschen nicht markieren.'"),
					String(DocObject.Ref));
			EndIf;
			
			CommonClientServer.MessageToUser(MessageText);
			
		EndTry;
		
	EndDo;
	
	Return ProcessedDocuments;
	
EndFunction

&AtClient
Procedure OrdersSettingsEnd(Result, AdditionalParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	// begin Drive.FullVersion
	Result.Property("IncludeInProductionPlanning", IncludeInProductionPlanning);
	// end Drive.FullVersion
	Result.Property("PostOrders", PostOrders);
	Result.Property("SetOrderStatusInProgress", SetOrderStatusInProgress);
	Result.Property("UseGroupProductsBySupplier", UseGroupProductsBySupplier);
	Result.Property("UseGroupProductsBySubcontractor", UseGroupProductsBySubcontractor);
	
EndProcedure

&AtServer
Procedure RestoreSettings()
	
	Var UserSettings;
	
	SettingsValue = CommonSettingsStorage.Load("DataProcessor.DemandPlanning", "AllProduction");
	UpdateChoiceListReplenishmentMethod();
	
	If TypeOf(SettingsValue) = Type("Structure") Then
		
		SettingsValue.Property("PeriodDuration", PeriodDuration);
		SettingsValue.Property("Counterparty", Counterparty);
		SettingsValue.Property("Company", Company);
		SettingsValue.Property("OnlyDeficit", OnlyDeficit);
		SettingsValue.Property("RecommendationsMode", RecommendationsMode);
		SettingsValue.Property("PostOrders", PostOrders);
		SettingsValue.Property("SetOrderStatusInProgress", SetOrderStatusInProgress);
		SettingsValue.Property("UseGroupProductsBySupplier", UseGroupProductsBySupplier);
		SettingsValue.Property("UseGroupProductsBySubcontractor", UseGroupProductsBySubcontractor);
		
		// begin Drive.FullVersion
		If GetFunctionalOption("UseProductionSubsystem") And GetFunctionalOption("UseProductionPlanning") Then
			SettingsValue.Property("IncludeInProductionPlanning", IncludeInProductionPlanning);
		Else
			IncludeInProductionPlanning = False;
		EndIf;
		// end Drive.FullVersion
	Else
		
		OnlyDeficit = True;
		SetOrderStatusInProgress = True;
		PostOrders = True;
		
	EndIf;
	
	If SettingsValue <> Undefined Then
		SetFilterReplenishmentMethod(SettingsValue.ReplenishmentMethod);
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	PeriodDuration = DriveServer.DateDiff(CurrentSessionDate(), EndOfPeriod, Enums.Periodicity.Day);
	
	Settings = New Structure;
	Settings.Insert("PeriodDuration", PeriodDuration);
	Settings.Insert("Counterparty", Counterparty);
	Settings.Insert("Company", Company);
	Settings.Insert("OnlyDeficit", OnlyDeficit);
	Settings.Insert("RecommendationsMode", RecommendationsMode);
	// begin Drive.FullVersion
	Settings.Insert("IncludeInProductionPlanning", IncludeInProductionPlanning);
	// end Drive.FullVersion
	Settings.Insert("PostOrders", PostOrders);
	Settings.Insert("SetOrderStatusInProgress", SetOrderStatusInProgress);
	Settings.Insert("UseGroupProductsBySupplier", UseGroupProductsBySupplier);
	Settings.Insert("UseGroupProductsBySubcontractor", UseGroupProductsBySubcontractor);
	
	Settings.Insert("ReplenishmentMethod", ReplenishmentMethod);
	
	CommonSettingsStorage.Save("DataProcessor.DemandPlanning", "AllProduction", Settings);
	
EndProcedure

&AtServer
Procedure SetFilterReplenishmentMethod(SelectedMethods)
	
	FilterReplenishmentMethod = "";
	
	For Each ValueListItem In SelectedMethods Do
		If ValueListItem.Check Then
			FilterReplenishmentMethod = FilterReplenishmentMethod + String(ValueListItem.Value) + ", ";
		EndIf;
		
		SettingsListItem = ReplenishmentMethod.FindByValue(ValueListItem.Value);
		If SettingsListItem <> Undefined Then
			SettingsListItem.Check = ValueListItem.Check;
		EndIf;

	EndDo;
	 
	FilterReplenishmentMethod = Left(FilterReplenishmentMethod, StrLen(FilterReplenishmentMethod) - 2);
	
EndProcedure

// begin Drive.FullVersion

&AtClient
Procedure ShowGenerateWIP(ProductionOrder)

	If TypeOf(ProductionOrder) <> Type("DocumentRef.ProductionOrder") Then
		Return;
	EndIf;
	
	If OrderHasProductionOperationKind(ProductionOrder) Then
		OpenForm("Document.ProductionOrder.Form.PassingForExecution", New Structure("ProductionOrder", ProductionOrder));
	Else
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot generate Work-in-progress from this Production order. You can generate Work-in-progress from Production orders whose Process type is Production.'; ru = 'Не удается создать документ ""Незавершенное производство"" на основании этого заказа на производство. ""Незавершенное производство"" можно создать на основании заказа на производство с типом процесса ""Производство"".';pl = 'Nie można wygenerować Pracy w toku z tego Zlecenia produkcyjnego. Możesz wygenerować Pracę w toku, w której typem procesu jest Produkcja.';es_ES = 'No se puede generar Trabajo en progreso desde esta Orden de producción. Se puede generar Trabajo en progreso a partir de Órdenes de producción cuyo tipo de proceso es Producción.';es_CO = 'No se puede generar Trabajo en progreso desde esta Orden de producción. Se puede generar Trabajo en progreso a partir de Órdenes de producción cuyo tipo de proceso es Producción.';tr = 'Bu Üretim emrinden İşlem bitişi oluşturulamıyor. İşlem bitişini, Süreç türü Üretim olan Üretim emirlerinden oluşturabilirsiniz.';it = 'Impossibile creare Lavoro in corso da questo Ordine di produzione. È possibile creare un Lavoro in corso dagli Ordini di produzione il cui Tipo processo è Produzione.';de = 'Fehler beim Generieren der Arbeit in Bearbeitung aus diesem Produktionsauftrag. Sie können Arbeit in Bearbeitung aus Produktionsaufträgen mit dem Prozesstyp Produktion generieren.'"));
	EndIf
	
EndProcedure

&AtServerNoContext
Function OrderHasProductionOperationKind(Order)
	
	Documents.ManufacturingOperation.CheckAbilityOfEnteringByWorkInProgress(Order, Common.ObjectAttributesValues(Order, "Posted"));

	Return (Common.ObjectAttributeValue(Order, "OperationKind") = Enums.OperationTypesProductionOrder.Production);
	
EndFunction

// end Drive.FullVersion

&AtServerNoContext
Function SelectedValueList(ReplenishmentMethod)
	
	SelectedValueList = New Array;
	
	For Each ValueListItem In ReplenishmentMethod Do
		If ValueListItem.Check Then
			SelectedValueList.Add(ValueListItem.Value);
		EndIf;
	EndDo;
	
	Return SelectedValueList;
	
EndFunction

&AtServer
Function IsGroupProductsBySubcontractor()
	
	IsGroupProductsBySubcontractor = False;
	
	If CanReceiveSubcontractingServices Then
		Processing = Enums.InventoryReplenishmentMethods.Processing;
		For Each Method In ReplenishmentMethod Do
			If Method.Value = Processing And Method.Check Then
				IsGroupProductsBySubcontractor = True;
			EndIf;
		EndDo;
	EndIf;

	Return IsGroupProductsBySubcontractor;
	
EndFunction

#EndRegion

#Region Initialize

ExecuteClose = False;

#EndRegion