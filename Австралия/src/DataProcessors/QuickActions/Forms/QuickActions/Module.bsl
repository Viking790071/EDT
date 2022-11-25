
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Initialization(Cancel);
	
	If Cancel Then
		Return;
	EndIf; 
	
	LoadSettings();
	CreateItemsQuickActions();
	
	AddressOfQuickActionSettings = PutToTempStorage(QuickActionSettings.Unload(), UUID);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If SelectedValue.Event = "QuickActionSetting" Then
		
		AddedQuickActions.Clear();
		
		For Each ID In SelectedValue.QuickActions Do
			AddedQuickActions.Add().ID = ID;
		EndDo;
		
		SaveQuickActionSettingServer();

	EndIf;	
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure Attachable_QuickActionClick(Item)
	
	ID = StrReplace(Item.Name, "QuickAction", "");
	ExecuteQuickAction(ID);
	
	#If WebClient Then
		
	If Items.Find("QuickActionSetting")<>Undefined Then
		CurrentItem = Items.QuickActionSetting;
	EndIf; 
	
	#EndIf 
	
EndProcedure

#EndRegion 

#Region InternalProceduresAndFunctions

&AtServer
Procedure Initialization(Cancel)
	
	FullRights				= IsInRole("FullRights");
	SalesAvailable			= (IsInRole("AddEditSalesSubsystem") OR FullRights);
	PurchasesAvailable		= (IsInRole("AddEditPurchasesSubsystem") OR FullRights);
	CashFundAvailable		= (IsInRole("AddEditPettyCashSubsystem") OR FullRights);
	AddingGoodsAvailable	= (IsInRole("AddEditProducts") OR FullRights);
	
	If GetFunctionalOption("UseRetail") AND SalesAvailable Then
		AddQuickAction("CashierWorkPlace", NStr("en = 'Cashier workplace'; ru = 'РМК';pl = 'Miejsce pracy kasjera';es_ES = 'Lugar de trabajo del cajero';es_CO = 'Lugar de trabajo del cajero';tr = 'Kasiyer çalışma alanı';it = 'Posto di lavoro cassiere';de = 'Kassierer Arbeitsplatz'"), "QuickActionOpenCWP");
	EndIf;
	
	If SalesAvailable Then
		AddQuickAction("AddSalesOrder", NStr("en = 'Sales order (Create)'; ru = 'Заказ покупателя (создание)';pl = 'Zamówienie sprzedaży (Tworzenie)';es_ES = 'Orden de ventas (Crea)';es_CO = 'Orden de ventas (Crea)';tr = 'Satış siparişi (Oluştur)';it = 'Ordine cliente (Crea)';de = 'Kundenauftrag (Erstellen)'"), "QuickActionCreateSalesOrder");
		AddQuickAction("AddProformaInvoice", NStr("en = 'Quote (Create)'; ru = 'Коммерческое предложение (создание)';pl = 'Oferta cenowa (Tworzenie)';es_ES = 'Presupuesto (Crear)';es_CO = 'Presupuesto (Crear)';tr = 'Teklif (Oluştur)';it = 'Quota (Crea)';de = 'Angebot (Erstellen)'"), "QuickActionCreateProformaInvoice");
		AddQuickAction("AddSalesInvoice", NStr("en = 'Sales invoice (Create)'; ru = 'Инвойс покупателю (создание)';pl = 'Faktura sprzedaży (Tworzenie)';es_ES = 'Factura de ventas (Crear)';es_CO = 'Factura de ventas (Crear)';tr = 'Satış faturası (Oluştur)';it = 'Fattura di vendita (Crea)';de = 'Verkaufsrechnung (Erstellen)'"), "QuickActionCreateSalesInvoice");
	EndIf;
	
	If PurchasesAvailable Then
		AddQuickAction("AddPurchaseOrder", NStr("en = 'Purchase order (Create)'; ru = 'Заказ поставщику (создание)';pl = 'Zamówienie zakupu (Tworzenie)';es_ES = 'Orden de compra (Crear)';es_CO = 'Orden de compra (Crear)';tr = 'Satın alma siparişi (Oluştur)';it = 'Ordine di acquisto (Crea)';de = 'Bestellung an Lieferanten (Erstellen)'"), "QuickActionCreatePurchaseOrder");
	EndIf;
	
	If CashFundAvailable Then
		AddQuickAction("AddReceiptToCashFund", NStr("en = 'Cash receipt (Create)'; ru = 'Приходный кассовый ордер (создание)';pl = 'KP - Dowód wpłaty (Tworzenie)';es_ES = 'Recibo de efectivo (Crear)';es_CO = 'Recibo de efectivo (Crear)';tr = 'Nakit tahsilat (Oluştur)';it = 'Entrata di cassa (Crea)';de = 'Zahlungseingang (Erstellen)'"), "QuickActionCreateReceiptToCashFund");
		AddQuickAction("AddExpenseFromCashFund", NStr("en = 'Cash voucher (Create)'; ru = 'Расходный кассовый ордер (создание)';pl = 'Dowód kasowy KW (Tworzenie)';es_ES = 'Vale de efectivo (Crear)';es_CO = 'Vale de efectivo (Crear)';tr = 'Nakit ödeme (Oluştur)';it = 'Uscita di cassa (Crea)';de = 'Kassenbeleg (Erstellen)'"), "QuickActionCreateExpenseFromCashFund");
	EndIf;
	
	If SalesAvailable Then
		AddQuickAction("SalesOrderList", NStr("en = 'Sales orders'; ru = 'Заказы покупателей';pl = 'Zamówienia sprzedaży';es_ES = 'Órdenes de ventas';es_CO = 'Órdenes de ventas';tr = 'Satış siparişleri';it = 'Ordini Cliente';de = 'Kundenaufträge'"), "QuickActionSalesOrderList");
		AddQuickAction("SalesInvoiceList", NStr("en = 'Sales invoices'; ru = 'Инвойсы покупателям';pl = 'Faktury sprzedaży';es_ES = 'Facturas de ventas';es_CO = 'Facturas de ventas';tr = 'Satış faturaları';it = 'Fatture di vendita';de = 'Verkaufsrechnungen'"), "QuickActionSalesInvoiceList");
	EndIf; 
	
	If CashFundAvailable Then
		AddQuickAction("CashDocumentList", NStr("en = 'Cash'; ru = 'Наличные';pl = 'Gotówka';es_ES = 'En efectivo';es_CO = 'En efectivo';tr = 'Nakit';it = 'Contanti';de = 'Barmittel'"), "QuickActionCashDocumentJournal");
	EndIf;
	
	If PurchasesAvailable Then
		AddQuickAction("SupplierInovoiceList", NStr("en = 'Supplier invoices'; ru = 'Инвойсы поставщиков';pl = 'Faktury zakupu';es_ES = 'Facturas de proveedor';es_CO = 'Facturas del proveedor';tr = 'Satın alma faturaları';it = 'Fatture fornitori';de = 'Eingangsrechnungen'"), "QuickActionSupplierInovoiceList");
	EndIf; 
	
	If AddingGoodsAvailable Then
		AddQuickAction("ProductsList", NStr("en = 'Products'; ru = 'Номенклатура';pl = 'Produkty';es_ES = 'Productos';es_CO = 'Productos';tr = 'Ürünler';it = 'Articoli';de = 'Produkte'"), "QuickActionProductsList");
	EndIf;
	
	If SalesAvailable Then
		AddQuickAction("CustomerList", NStr("en = 'Customers'; ru = 'Покупатели';pl = 'Kontrahenci';es_ES = 'Clientes';es_CO = 'Clientes';tr = 'Müşteriler';it = 'Clienti';de = 'Kunden'"), "QuickActionCustomerList");
	EndIf;
	
	If PurchasesAvailable Then
		AddQuickAction("SupplierList", NStr("en = 'Suppliers'; ru = 'Поставщики';pl = 'Dostawcy';es_ES = 'Proveedores';es_CO = 'Proveedores';tr = 'Tedarikçiler';it = 'Fornitori';de = 'Lieferanten'"), "QuickActionSupplierList");
	EndIf; 
	
	If QuickActionSettings.Count() = 0 Then
		Cancel = True;
		Return;
	EndIf; 
	
	// Other initialization operations	
	IdentifyWhetherBalanceEntered();
	
EndProcedure

&AtServer
Procedure IdentifyWhetherBalanceEntered()
	
	If Not IsInRole("FullRights") Then
		Return;
	EndIf; 
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	Funds.Recorder
	|FROM
	|	AccumulationRegister.CashAssets AS Funds
	|WHERE
	|	NOT Funds.Recorder REFS Document.OpeningBalanceEntry
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	InventoryInWarehouses.Recorder
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|WHERE
	|	NOT InventoryInWarehouses.Recorder REFS Document.OpeningBalanceEntry
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	SettlementsWithCustomers.Recorder
	|FROM
	|	AccumulationRegister.AccountsReceivable AS SettlementsWithCustomers
	|WHERE
	|	NOT SettlementsWithCustomers.Recorder REFS Document.OpeningBalanceEntry
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	SettlementsWithSuppliers.Recorder
	|FROM
	|	AccumulationRegister.AccountsPayable AS SettlementsWithSuppliers
	|WHERE
	|	NOT SettlementsWithSuppliers.Recorder REFS Document.OpeningBalanceEntry";
	
	Result = Query.ExecuteBatch();
	ThereBalanceInput = (Not Result.Get(0).IsEmpty() OR Not Result.Get(1).IsEmpty() OR Not Result.Get(2).IsEmpty() OR Not Result.Get(3).IsEmpty());
	
EndProcedure

&AtServer
Procedure LoadSettings()
	
	QuickActionTable = Common.CommonSettingsStorageLoad("BusinessPulse", "QuickActions");
	
	If QuickActionTable = Undefined Then
		QuickActionsByDefault();
	Else		
		AddedQuickActions.Clear();
		
		For Each Str In QuickActionTable Do
			
			FilterStructure = New Structure;
			FilterStructure.Insert("ID", Str.ID);
			
			Rows = QuickActionSettings.FindRows(FilterStructure);
			If Rows.Count() = 0 Then
				// Insufficient rights or obsolete quick action
				Continue;
			EndIf;
			
			NewRow = AddedQuickActions.Add();
			NewRow.ID = Str.ID;
			
		EndDo;		
	EndIf; 
	
EndProcedure

&AtServer
Procedure SaveSettings(SettingsKind)
	
	If IsBlankString(SettingsKind) OR SettingsKind = "QuickActions" Then
		Tab = AddedQuickActions.Unload(, "ID");
		Common.CommonSettingsStorageSave("BusinessPulse", "QuickActions", Tab);
	EndIf; 
	
EndProcedure

&AtServer
Procedure QuickActionsByDefault()
	
	DisplayQuickAction("CustomerList");
	DisplayQuickAction("ProductsList");		
	DisplayQuickAction("AddSalesOrder");
	DisplayQuickAction("SalesOrderList");
	DisplayQuickAction("SalesInvoiceList");
	DisplayQuickAction("AddPurchaseOrder");
	DisplayQuickAction("SupplierInovoiceList");	
	
	SaveSettings("QuickActions");
	
EndProcedure

&AtServer
Procedure AddQuickAction(ID, Presentation, PictureName)
	
	TabularSectionRow = QuickActionSettings.Add();
	TabularSectionRow.ID			= ID;
	TabularSectionRow.Presentation	= Presentation;
	TabularSectionRow.PictureName	= PictureName;
	
EndProcedure

&AtServer
Procedure DisplayQuickAction(ID)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("ID", ID);
	
	AddedLines = AddedQuickActions.FindRows(FilterStructure);
	If AddedLines.Count() > 0 Then
		Return;
	EndIf; 
	
	Rows = QuickActionSettings.FindRows(FilterStructure);
	If Rows.Count() = 0 Then
		// Insufficient rights or obsolete quick action
		Return;
	EndIf; 
	
	NewRow = AddedQuickActions.Add();
	NewRow.ID = ID;
	
EndProcedure

&AtServer
Procedure SaveQuickActionSettingServer()
	
	SaveSettings("QuickActions");
	CreateItemsQuickActions();
	
EndProcedure

&AtServer
Procedure CreateItemsQuickActions()
	
	DeleteItemsRecursively(Items.GroupQuickActions); 
	
	For Each Str In AddedQuickActions Do
		
		ItemName	= "QuickAction" + Str.ID;
		GroupName	= "QuickActionGroup" + Str.ID;
		TitleName	= "TitleQuickAction" + Str.ID;
		
		If Items.Find(ItemName) <> Undefined Then
			Continue;
		EndIf; 
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ID", Str.ID);
		
		SettingLines = QuickActionSettings.FindRows(SearchStructure);
		For Each SettingPage In SettingLines Do
			
			FormGroup			= Items.Add(GroupName, Type("FormGroup"), Items.GroupQuickActions);
			FormGroup.Type		= FormGroupType.UsualGroup;
			FormGroup.ShowTitle	= False;
			FormGroup.Group		= ChildFormItemsGroup.Vertical;
			
			Item				= Items.Add(ItemName, Type("FormDecoration"), FormGroup);
			Item.Type			= FormDecorationType.Picture;
			Item.Hyperlink		= True;
			Item.Width			= 7;
			Item.Height			= 3;
			Item.PictureSize	= PictureSize.Proportionally;
			Item.Tooltip		= SettingPage.Presentation;
			
			If Not IsBlankString(SettingPage.PictureName) Then
				Item.Picture = PictureLib[SettingPage.PictureName];
			EndIf; 
			
			Item.SetAction("Click", "Attachable_QuickActionClick");
			
		EndDo;
		
	EndDo;
	
	Item				= Items.Add("QuickActionSetting", Type("FormDecoration"), Items.GroupQuickActions);
	Item.Type			= FormDecorationType.Picture;
	Item.Hyperlink		= True;
	Item.Width			= 2;
	Item.Height			= 3;
	Item.PictureSize	= PictureSize.RealSize;
	Item.Tooltip		= NStr("en = 'Settings'; ru = 'Настройки';pl = 'Ustawienia';es_ES = 'Configuraciones';es_CO = 'Configuraciones';tr = 'Ayarlar';it = 'Impostazioni';de = 'Einstellungen'");
	Item.Picture		= PictureLib.BusinessPulseSetUpQuickActions;
	
	Item.SetAction("Click", "Attachable_QuickActionClick");
	
EndProcedure

&AtServer
Procedure DeleteItemsRecursively(FormGroup)
	
	While FormGroup.ChildItems.Count() > 0 Do
		
		Item = FormGroup.ChildItems[0];
		
		If TypeOf(Item) = Type("FormButton") Then
			Commands.Delete(Item.CommandName);
		ElsIf TypeOf(Item) = Type("FormGroup") Then
			DeleteItemsRecursively(Item);
		EndIf;
		
		Items.Delete(Item);
		
	EndDo; 
	
EndProcedure

&AtClient
Procedure ExecuteQuickAction(ID)
	
	If ID = "AddSalesOrder" Then
		OpenForm("Document.SalesOrder.ObjectForm");
	ElsIf ID = "AddProformaInvoice" Then
		OpenForm("Document.Quote.ObjectForm");
	ElsIf ID = "AddSalesInvoice" Then
		OpenForm("Document.SalesInvoice.ObjectForm");
	ElsIf ID = "AddPurchaseOrder" Then
		OpenForm("Document.PurchaseOrder.ObjectForm");
	ElsIf ID = "AddReceiptToCashFund" Then
		OpenForm("Document.CashReceipt.ObjectForm");
	ElsIf ID = "AddExpenseFromCashFund" Then
		OpenForm("Document.CashVoucher.ObjectForm");
	ElsIf ID = "SalesOrderList" Then
		OpenForm("Document.SalesOrder.ListForm");
	ElsIf ID = "CashDocumentList" Then
		OpenForm("DocumentJournal.CashDocuments.ListForm");
	ElsIf ID = "SalesInvoiceList" Then
		OpenForm("Document.SalesInvoice.ListForm");
	ElsIf ID = "SupplierInovoiceList" Then
		OpenForm("Document.SupplierInvoice.ListForm");
	ElsIf ID = "ProductsList" Then
		OpenForm("Catalog.Products.ListForm");
	ElsIf ID = "CustomerList" Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", New Structure("Customer", True));
		FormParameters.Insert("PurposeUseKey", "CustomerList");
		
		OpenForm("Catalog.Counterparties.ListForm", FormParameters);
		
	ElsIf ID = "SupplierList" Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", New Structure("Supplier", True));
		FormParameters.Insert("PurposeUseKey", "SupplierList");
		
		OpenForm("Catalog.Counterparties.ListForm", FormParameters);
		
	ElsIf ID = "CashierWorkPlace" Then
		
		ParametersStructure = CashierWorkplaceServerCall.GetDefaultCashRegisterAndTerminal();
		EquipmentManagerClient.RefreshClientWorkplace();
		
		If RequiredToOpenCashFundSelectionWindow(ParametersStructure) Then
			OpenForm("Document.SalesSlip.Form.DocumentForm_CWP_WindowPettyCashSelection", 
				New Structure("ParametersStructure", ParametersStructure));
		Else
			OpenForm("Document.SalesSlip.Form.DocumentForm_CWP", ParametersStructure);
		EndIf;
		
	ElsIf ID = "Setting" Then
		
		OpeningStructure = New Structure;
		IDs = New Array;
		
		For Each Str In AddedQuickActions Do
			IDs.Add(Str.ID);
		EndDo; 
		
		OpeningStructure.Insert("AddedQuickActions", IDs);
		OpeningStructure.Insert("AddressOfQuickActionSettings", AddressOfQuickActionSettings);
		OpeningStructure.Insert("ThereBalanceInput", ThereBalanceInput);
		
		OpenForm("DataProcessor.QuickActions.Form.QuickActionSettingForm", OpeningStructure, ThisObject);
		
	EndIf; 	
	
EndProcedure

&AtClient
Function RequiredToOpenCashFundSelectionWindow(ParametersStructure)
	
	If Not ValueIsFilled(ParametersStructure.CashCR) Then
		Return True;
	EndIf;
	
	If ValueIsFilled(ParametersStructure.POSTerminalQuantity)
		AND Not ValueIsFilled(ParametersStructure.POSTerminal) Then
			Return True;
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion
 