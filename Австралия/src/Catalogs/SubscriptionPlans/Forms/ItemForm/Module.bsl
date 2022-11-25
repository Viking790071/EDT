
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		
		If Parameters.CopyingValue.IsEmpty() Then
			
			Object.ActionOnCreating = Enums.ActionsOnInvoiceCreating.SaveAsDraft;
			Object.ChargeFrequency = Enums.Periodicity.Month;
			
			If Parameters.PurchaseDocumentsSchedule Then
				
				Object.TypeOfDocument = DocumentsNamePurchaseOrder();
				
			Else
				
				Object.TypeOfDocument = DocumentsNameSalesInvoice();
				
			EndIf;
			
		Else 
			
			CopyingTemplate	= Common.ObjectAttributeValue(Parameters.CopyingValue, "Template");
			
			If ValueIsFilled(CopyingTemplate) Then
				
				IsNeedSubscriptionForTemplate = True;
				
			EndIf;
			
		EndIf;
		
	Else 
		
		If Object.TypeOfDocument <> "SalesInvoice" Then
			
			Parameters.PurchaseDocumentsSchedule = True;
			
		EndIf;
		
	EndIf;
		
	FillPrintFormToPrintChoiceList();
	
	PeriodRepresentationParameter = Catalogs.SubscriptionPlans.PeriodRepresentationParameter();
	
	CurrentPageName = Items.GroupPages.CurrentPage.Name;
	
	StructureData = GetInventoryStructureData();
	
	If Not Object.Ref.IsEmpty() Then
		
		TableSubscriptions.Load(GetTableSubscriptions());
		
	EndIf;
	
	UseTaxInvoices = StructureData.UseTaxInvoices;
	Items.InventoryProducts.ChoiceParameters = StructureData.ProductsChoiceParameters;
		
	SetSubscriptionsFilter();
	SetDocumentsFilter();
	
	UseContracts = Constants.UseContractsWithCounterparties.Get();
	
	UseTemplate = ValueIsFilled(Object.Template);
	
	If UseTemplate Then
		
		FillInventoryTemplate();
		
	EndIf;
	
	OldTemplate = Object.Template;
	
	If Object.UseCustomSchedule Then
		FillValueTableUserDefinedSchedule(True);
	EndIf;
	
	If Object.Enabled Then
		// StandardSubsystems.ObjectAttributesLock
		ObjectAttributesLock.LockAttributes(ThisObject);
		// End StandardSubsystems.ObjectAttributesLock
		
		IsLockAttributes = True;
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If IsLockAttributes
		And Object.Enabled
		And ObjectAttributesLockClient.Attributes(ThisObject).Count() > 0 Then
		
		Items.JobShedule.Enabled			= False;
		Items.UseTemplate.Enabled			= False;
		Items.TableSubscriptions.ReadOnly	= True;
	
	EndIf;
	
	FillTypeOfDocumentChoiceList(Parameters.PurchaseDocumentsSchedule);
	
	SetScheduleButtonTitle();
	SetPagesTitles();
	SetConditionalAppearance();
	SetContractsVisible();
	SetVisibleCommandGroupTrigger();
	SetEnabledLinkCustomSchedule();
	SetEnabledProductsGroupAddParameter();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetPrivilegedMode(True);
	
	Job = ScheduledJobsServer.Job(CurrentObject.ScheduledJobUUID);
	
	If Job = Undefined Then
		Schedule = Undefined;
	Else
		Schedule = Job.Schedule;
	EndIf;

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ArrayMessages = New Array;
	
	CheckScheduleBeforeWriteAtServer(Cancel, ArrayMessages);
	
	For Each ItemArray In ArrayMessages Do
		
		CommonClientServer.MessageToUser(ItemArray.TextMessage, , ItemArray.FieldForm);
		
	EndDo;
	
	If Cancel Then
		
		Object.Enabled = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Object.UseCustomSchedule Then
		
		If Not ValueIsFilled(Object.UserDefinedDateType) Then
			
			DateType = "Working";
			
		EndIf;
		
		If Not ValueIsFilled(Object.UserDefinedCalculateFrom) Then
			
			CalculateFrom = "Begin";
			
		EndIf;
		
		RecordSetSubscriptions = InformationRegisters.Subscriptions.CreateRecordSet();
		
		RecordSetSubscriptions.Filter.SubscriptionPlan.Set(Object.Ref);
		RecordSetSubscriptions.Read();
		
		For Each RecordSubscription In RecordSetSubscriptions Do
		
			RecordSubscription.StartDate = Object.UserDefinedStartDate;
			RecordSubscription.EndDate = Object.UserDefinedEndDate;
		
		EndDo;
		
		RecordSetSubscriptions.Write();
		
		If Not ValueIsFilled(Object.ScheduledJobUUID) Then
			
			Schedule = New JobSchedule;
			Schedule.DaysRepeatPeriod = 1;
			
			ScheduledJob = ScheduledJobs.CreateScheduledJob(Metadata.ScheduledJobs.CreateDocumentsOnSubscription);
			ScheduledJob.Schedule = Schedule;
			ScheduledJob.Write();
			
			Object.ScheduledJobUUID = ScheduledJob.UUID;
			
		Else 
			
			Schedule = New JobSchedule;
			Schedule.DaysRepeatPeriod = 1;
			
		EndIf;
		
	EndIf;
	
	If Schedule = Undefined Then 
		Return;
	EndIf;
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.CreateDocumentsOnSubscription);
	JobParameters.Insert("MethodName", Metadata.ScheduledJobs.CreateDocumentsOnSubscription.MethodName);
	
	MethodParameters = New Array;
	
	If CurrentObject.Ref = Catalogs.SubscriptionPlans.EmptyRef() Then 
		
		NewRef = Catalogs.SubscriptionPlans.GetRef(New UUID());
		CurrentObject.SetNewObjectRef(NewRef);
		MethodParameters.Add(NewRef);
		
	Else 
		
		MethodParameters.Add(CurrentObject.Ref);
		
	EndIf;
	
	JobParameters.Insert("Parameters", MethodParameters);
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	
	If Object.TypeOfDocument = "SupplierInvoice" Then
		
		ObjectPresentation = NStr("en = 'supplier invoice schedule'; ru = 'график инвойса поставщика';pl = 'harmonogram faktury zakupu';es_ES = 'horario de factura de compra';es_CO = 'horario de factura de compra';tr = 'satın alma faturası programı';it = 'fattura di acquisto programma';de = 'lieferantenrechnungszeitplan'");
		
	ElsIf Object.TypeOfDocument = "PurchaseOrder" Then
		
		ObjectPresentation = NStr("en = 'purchase order schedule'; ru = 'график заказов поставщику';pl = 'harmonogram zamówień zakupu';es_ES = 'horario de la orden de compra';es_CO = 'horario de la orden de compra';tr = 'satın alma siparişi planı';it = 'programma ordini di acquisto';de = 'zeitplan für bestellung an lieferanten'");
		
	Else 
		
		ObjectPresentation = NStr("en = 'subscription plan'; ru = 'план подписки';pl = 'plan subskrypcji';es_ES = 'plan de suscripción';es_CO = 'plan de suscripción';tr = 'abonelik planı';it = 'piano di abbonamento';de = 'Abonnement-Plan'");
		
	EndIf;
	
	If Not IsBlankString(ObjectPresentation) Then
		ObjectPresentation = " (" + ObjectPresentation + ")";
	EndIf;
	
	JobDescription = CurrentObject.Description + ObjectPresentation; 
	
	JobParameters.Insert("Description", JobDescription);
	JobParameters.Insert("Use", CurrentObject.Enabled);
	JobParameters.Insert("Schedule", Schedule);
	
	JobIsFound = False;
	For Each Job In JobsList Do
		If Job.UUID = CurrentObject.ScheduledJobUUID Then
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
			JobIsFound = True;
		EndIf;
	EndDo;
	
	If Not JobIsFound Then
		Job = ScheduledJobsServer.AddJob(JobParameters);
		CurrentObject.ScheduledJobUUID = Job.UUID;
	EndIf;

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetSubscriptionsFilter();
	SetDocumentsFilter();
	
	If IsNeedSubscriptionForTemplate Then
	
		SetSubscriptionForTemplate();
		
		IsNeedSubscriptionForTemplate = False;
	
	EndIf; 
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	SetConditionalAppearance();
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.UseCustomSchedule 
		And IsCustomScheduleChanged Then
		
		If CompareUserDefinedSchedule.Count() = 0 Then
			
			For Each LineSchedule In UserDefinedSchedule Do
				
				AddValueUserDefinedSchedule(LineSchedule.PlannedDate, CurrentObject.Ref);
				
			EndDo;
			
		Else 
			
			ListDeletedDates = New ValueList;
			
			For Each LineCompareSchedule In CompareUserDefinedSchedule Do
				
				FilterCompare = New Structure("PlannedDate", LineCompareSchedule.PlannedDate);
				
				FindedRows = UserDefinedSchedule.FindRows(FilterCompare);
				
				If FindedRows.Count() = 0 Then
					
					ListDeletedDates.Add(LineCompareSchedule.PlannedDate);
					
				ElsIf FindedRows.Count() = 1 Then
					
					UserDefinedSchedule.Delete(FindedRows[0]);
					
				EndIf;
				
			EndDo;
			
			For Each LineSchedule In UserDefinedSchedule Do
				
				AddValueUserDefinedSchedule(LineSchedule.PlannedDate, CurrentObject.Ref);
				
			EndDo;
			
			For Each ItemList In ListDeletedDates Do
			
				DeleteValueUserDefinedSchedule(ItemList.Value, CurrentObject.Ref);
			
			EndDo;
			
			FillValueTableUserDefinedSchedule();
			
			CompareUserDefinedSchedule.Load(UserDefinedSchedule.Unload());
			
		EndIf;
		
	EndIf;
	
	If IsSubscriptionsChanged Then
	
		SetRecordsSubscriptions(CurrentObject.Ref);
	
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure GroupPagesOnCurrentPageChange(Item, CurrentPage)
	
	CurrentPageName = CurrentPage.Name;
	
EndProcedure

&AtClient
Procedure BeforeCurrentPageChange(Result, Parameters) Export
	
	If Result = DialogReturnCode.OK Then
		If Write() Then
			CurrentItem = Parameters.CurrentPage;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure TypeOfDocumentOnChange(Item)
	
	If ValueIsFilled(Object.Template)
		And Object.TypeOfDocument <> "SupplierInvoice" Then
		
		Object.Template = PredefinedValue("Document.SupplierInvoice.EmptyRef");
		
	EndIf;
	
	If Not ValueIsFilled(Object.TypeOfDocument) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Document type is required.'; ru = 'Требуется указать тип документа.';pl = 'Wymagany jest typ dokumentu.';es_ES = 'Se requiere el tipo de documento.';es_CO = 'Se requiere el tipo de documento.';tr = 'Belge türü gerekli.';it = 'È richiesto il tipo di documento.';de = 'Dokumententyp ist erforderlich.'"), , "Object.TypeOfDocument");
		Return;
			
	EndIf;
	
	StructureData = GetInventoryStructureData();
	
	If StructureData.RemovalProducts.Count() > 0 Then
		
		NotifyDescription = New NotifyDescription(
			"BeforeDeleteRemovalProducts", ThisObject, StructureData);
		
		If Object.TypeOfDocument = "SupplierInvoice" Then
			
			TextQuery = NStr("en = 'The Products list includes items with ""Work"" product type. 
				|They cannot be included in Supplier invoices. 
				|Do you want to delete these items from the Products list?'; 
				|ru = 'Список ""Номенклатура"" включает элементы с типом номенклатуры ""Работа"". 
				|Они не могут быть включены в инвойс поставщика. 
				|Удалить эти элементы из списка ""Номенклатура""?';
				|pl = 'Lista produktów zawiera elementy z typem produktu ""Praca"". 
				|Nie można ich uwzględnić w fakturach zakupu. 
				|Czy chcesz usunąć te elementy z listy produktów?';
				|es_ES = 'La lista de Productos incluye artículos con el tipo de producto ""Trabajo"". 
				|No pueden ser incluidos en las facturas de Proveedor. 
				|¿Quiere eliminar estos artículos de la lista de Productos?';
				|es_CO = 'La lista de Productos incluye artículos con el tipo de producto ""Trabajo"". 
				|No pueden ser incluidos en las facturas del Proveedor. 
				|¿Quiere eliminar estos artículos de la lista de Productos?';
				|tr = 'Ürünler listesi ""İş"" ürün türünde öğeler içeriyor. 
				|Bunlar satın alma faturalarına dahil edilemez. 
				|Bu öğeler Ürünler listesinden silinsin mi?';
				|it = 'L''elenco Articoli include elementi con il tipo di articolo ""Lavoro"". 
				|Non possono essere inclusi nelle Fatture di acquisto. 
				|Eliminare questi elementi dall''elenco Articoli?';
				|de = 'Die Produktliste enthält Artikel mit dem Produkttyp „Arbeit“. 
				|Sie können nicht in Lieferantenrechnungen eingeschlossen sein. 
				|Möchten Sie diese Artikel aus der Produktliste löschen?'");
			
		Else 
			
			TextQuery = NStr("en = 'The Products list includes items that cannot be included in Sales invoices. 
				|Do you want to delete these items from the Products list?'; 
				|ru = 'Список ""Номенклатура"" включает элементы, которые не могут быть включены в инвойсы покупателю.
				|Удалить эти элементы из списка Номенклатура?';
				|pl = 'Lista produktów zawiera elementy, których nie można ich uwzględnić w fakturach sprzedaży. 
				|Czy chcesz usunąć te elementy z listy produktów?';
				|es_ES = 'La lista de Productos incluye artículos que no pueden ser incluidos en las facturas de Venta.
				|¿Quiere eliminar estos artículos de la lista de Productos?';
				|es_CO = 'La lista de Productos incluye artículos que no pueden ser incluidos en las facturas de Venta.
				|¿Quiere eliminar estos artículos de la lista de Productos?';
				|tr = 'Ürünler listesi Satış faturalarına dahil edilemeyen öğeler içeriyor. 
				|Bu öğeler Ürünler listesinden silinsin mi?';
				|it = 'L''elenco Articoli include elementi che non possono essere inclusi nelle fatture di vendita. 
				|Eliminare questi elementi dall''elenco Articoli?';
				|de = 'Die Produktliste enthält Artikel, die nicht in Verkaufsrechnungen eingeschlossen werden können. 
				|Möchten Sie diese Artikel aus der Produktliste löschen?'");
			
		EndIf;
		
		ShowQueryBox(
			NotifyDescription, 
			TextQuery, 
			QuestionDialogMode.YesNo,,
			DialogReturnCode.No);
			
		Return;
		
	EndIf;
	
	ProcessingInventoryStructureData(StructureData);
	
	SetDocumentsFilter();
	SetPagesTitles();
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If CheckCompanyChangePossibility(Object.Ref, Object.Company) Then
		
		UseTaxInvoices = TaxInvoicesAreUsed(Object.TypeOfDocument, Object.Company);
		SetConditionalAppearance();
		
	Else
		CommonClientServer.MessageToUser(
			NStr("en = 'You cannot change the company of the subscription plan if there are subscribed customers exist.'; ru = 'Вы не можете изменить организацию плана подписки при наличии подписанных клиентов.';pl = 'Nie możesz zmienić firmy w planie subskrypcji jeżeli istnieją podpisani klienci.';es_ES = 'No se puede cambiar la empresa del plan de suscripción si existen clientes suscritos.';es_CO = 'No se puede cambiar la empresa del plan de suscripción si existen clientes suscritos.';tr = 'Abone olunan müşteriler varsa abonelik planının şirketini değiştiremezsiniz.';it = 'Impossibile modificare l''azienda del piano di abbonamento se esistono clienti che hanno sottoscritto.';de = 'Sie können die Firma des Abonnementplans nicht ändern, sofern abonnierte Kunden vorhanden sind.'"));
	EndIf;
		
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtClient
Procedure UseTemplateOnChange(Item)
	
	If Not UseTemplate Then
	
		Object.Template = PredefinedValue("Document.SupplierInvoice.EmptyRef");
		
		OldTemplate = Object.Template;
		
		IsNeedSubscriptionForTemplate = False;
	
	EndIf;
	
	SetAppearanceTemplate();
	
EndProcedure

&AtClient
Procedure TemplateOnChange(Item)
	
	If  Object.Template = OldTemplate Then
		
		Return;
		
	EndIf;
	
	If ValueIsFilled(Object.Template) 
		And Object.Inventory.Count() > 0 Then
		
		NotifyDescription = New NotifyDescription(
			"TemplateOnChangeEnd", ThisObject);
		
		ShowQueryBox(
			NotifyDescription, 
			NStr("en = 'The Products list and Schedules settings will be replaced 
				|with the data from the selected template. 
				|Do you want to continue?'; 
				|ru = 'Настройки списка Номенклатура и Графиков будут заменены 
				|данными из выбранного шаблона. 
				|Продолжить?';
				|pl = 'Ustawienia listy produktów i harmonogramów zostaną zastąpione 
				|danymi z wybranego szablonu. 
				|Czy chcesz kontynuować?';
				|es_ES = 'La lista de Productos y las configuraciones de los Horarios serán reemplazadas
				|por los datos del modelo seleccionado.
				|¿Quiere continuar?';
				|es_CO = 'La lista de Productos y las configuraciones de los Horarios serán reemplazadas
				|por los datos del modelo seleccionado.
				|¿Quiere continuar?';
				|tr = 'Ürünler listesi ve Program ayarları 
				|seçilen şablonun verileriyle değiştirilecek. 
				|Devam etmek istiyor musunuz?';
				|it = 'L''elenco Articoli e le impostazioni di Programmi saranno sostituiti 
				|con i dati dal modello selezionato. 
				|Continuare?';
				|de = 'Die Einstellungen für Produktliste und Zeitpläne werden 
				|durch die Daten aus der ausgewählten Vorlage ersetzt. 
				|Möchten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo,,
			DialogReturnCode.No);
			
		Return;
		
	ElsIf ValueIsFilled(Object.Template) Then
		
		SetCompanyAndCounterpartyFromTemplate();
		
		IsNeedSubscriptionForTemplate = True;
		
		FillInventoryTemplate();
		
	Else 
		
		IsNeedSubscriptionForTemplate = False;
		
	EndIf;
	
	OldTemplate = Object.Template;
	
	SetAppearanceTemplate();
	
EndProcedure

&AtClient
Procedure TemplateOnChangeEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.No Then
		
		Object.Template = OldTemplate;
		
	Else
		
		OldTemplate = Object.Template;
		
		Object.Inventory.Clear();
		
		IsNeedSubscriptionForTemplate = True;
		
		FillInventoryTemplate();
		
	EndIf;
	
	SetAppearanceTemplate();
	
EndProcedure

&AtClient
Procedure ChargeFrequencyOnChange(Item)
	
	SetVisibleCommandGroupTrigger();
	
EndProcedure

&AtClient
Procedure UseCustomScheduleOnChange(Item)
	
	If Object.UseCustomSchedule Then
		
		If Not ValueIsFilled(Object.UserDefinedDateType) Then
			
			Object.UserDefinedDateType = "Calendar";
			
		EndIf;
		
		If Not ValueIsFilled(Object.UserDefinedCalculateFrom) Then
			
			Object.UserDefinedCalculateFrom = "Begin";
			
		EndIf;
		
		If Object.UserDefinedDayOf = 0 Then
			
			Object.UserDefinedDayOf = 1;
			
		EndIf;
		
		If Object.UserDefinedStartDate = Date(1, 1, 1) Then
			
			Object.UserDefinedStartDate = BegOfMonth(GetCurrentSessionDate());
			
		EndIf;
		
		If Object.UserDefinedEndDate = Date(1, 1, 1) Then
			
			Object.UserDefinedEndDate = EndOfMonth(GetCurrentSessionDate());
			
		EndIf;
		
	EndIf;
	
	SetEnabledLinkCustomSchedule();
	
EndProcedure
	
&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region InventoryFormTableItemsEventHandlers

&AtClient
Procedure InventoryOnChange(Item)
	
	SetEnabledProductsGroupAddParameter();
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company",	Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	
EndProcedure

#EndRegion

#Region SalesInvoicesFormTableItemsEventHandlers

&AtClient
Procedure SalesInvoicesSelection(Item, SelectedRow, Field, StandardProcessing)
	OpenDocument(SelectedRow, StandardProcessing);	
EndProcedure

#EndRegion

#Region PurchaseOrdersFormTableItemsEventHandlers

&AtClient
Procedure PurchaseOrdersSelection(Item, SelectedRow, Field, StandardProcessing)
	OpenDocument(SelectedRow, StandardProcessing);
EndProcedure

#EndRegion

#Region SubscriptionsFormTableItemsEventHandlers

&AtClient
Procedure TableSubscriptionsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
		
	If ValueIsFilled(Object.Template) Then
		
		Return;
		
	EndIf;
	
	If Not ValueIsFilled(Object.TypeOfDocument) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Document type is required.'; ru = 'Требуется указать тип документа.';pl = 'Wymagany jest typ dokumentu.';es_ES = 'Se requiere el tipo de documento.';es_CO = 'Se requiere el tipo de documento.';tr = 'Belge türü gerekli.';it = 'È richiesto il tipo di documento.';de = 'Dokumententyp ist erforderlich.'"), , "Object.TypeOfDocument");
		Return;
			
	EndIf;
	
	If Not ValueIsFilled(Object.Company) Then
		
		If Object.TypeOfDocument = "SalesInvoice" Then
		
			CommonClientServer.MessageToUser(NStr("en = 'Company is required for a Subscription.'; ru = 'Для Подписки требуется указать Организацию.';pl = 'Do subskrypcji wymagana jest firma.';es_ES = 'Se requiere una empresa para la suscripción.';es_CO = 'Se requiere una empresa para la suscripción.';tr = 'Abonelik için İş yeri gerekli.';it = 'È richiesta l''azienda per l''Abbonamento.';de = 'Firma ist für ein Abonnement erforderlich.'"), , "Object.Company");
			Return;
			
		Else
			
			CommonClientServer.MessageToUser(NStr("en = 'Company is required for a Supplier schedule.'; ru = 'Для графика поставщика требуется указать Организацию.';pl = 'Wymagana jest firma dla harmonogramie dostawcy.';es_ES = 'Se requiere una empresa para el horario del Proveedor.';es_CO = 'Se requiere una empresa para el horario del Proveedor.';tr = 'Tedarikçi programı için İş yeri gerekli.';it = 'È richiesta l''Azienda per un programma Fornitore.';de = 'Firma ist für einen Lieferantenzeitplan erforderlich.'"), , "Object.Company");
			Return;
			
		EndIf;
		
	EndIf;
		
	FormParameters = New Structure;
	FormParameters.Insert("SubscriptionPlan", Object.Ref);
	FormParameters.Insert("Company", Object.Company);
	FormParameters.Insert("IsDimensionsReadOnly", ValueIsFilled(Object.Template));
	FormParameters.Insert("TypeOfDocument", Object.TypeOfDocument);
	FormParameters.Insert("IsNew", True);
	
	If Object.UseCustomSchedule Then
		
		FormParameters.Insert("IsResourcesReadOnly", True);
		FormParameters.Insert("StartDate", Object.UserDefinedStartDate);
		FormParameters.Insert("EndDate", Object.UserDefinedEndDate);
		
	EndIf;
	
	NotificationAfterAddRow = New NotifyDescription("TableSubscriptionsAfterAddRow", ThisObject);
		
	OpenForm("Catalog.SubscriptionPlans.Form.SubscriptionsRecordForm", 
		FormParameters,
		,,,,
		NotificationAfterAddRow);
	
EndProcedure

&AtClient
Procedure TableSubscriptionsAfterAddRow(NewRowResult, AdditionalParameters) Export
	
	If NewRowResult = Undefined Then
		
		Return;
		
	Else
		
		NewLine = TableSubscriptions.Add();
		
		FillPropertyValues(NewLine, NewRowResult);
		
		IsSubscriptionsChanged = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TableSubscriptionsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.TableSubscriptions.ReadOnly Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("SubscriptionPlan",	  Object.Ref);
	FormParameters.Insert("Company",			  Object.Company);
	FormParameters.Insert("IsDimensionsReadOnly", ValueIsFilled(Object.Template));
	FormParameters.Insert("IsResourcesReadOnly",  Object.UseCustomSchedule);
	FormParameters.Insert("TypeOfDocument",		  Object.TypeOfDocument);
	FormParameters.Insert("IsNew", False);
	
	DataRow = Item.CurrentData;
	
	FormParameters.Insert("Counterparty"		, DataRow.Counterparty);
	FormParameters.Insert("Contract"			, DataRow.Contract);
	FormParameters.Insert("EmailTo"				, DataRow.EmailTo);
	FormParameters.Insert("StartDate"			, DataRow.StartDate);
	FormParameters.Insert("EndDate"				, DataRow.EndDate);
	
	If Object.UseCustomSchedule Then
		
		FormParameters.Insert("IsResourcesReadOnly", True);
		FormParameters.Insert("StartDate", Object.UserDefinedStartDate);
		FormParameters.Insert("EndDate", Object.UserDefinedEndDate);
		
	EndIf;
	
	StructureAdditionalParameters = New Structure("Key", Item);
	
	NotificationSelection = New NotifyDescription("TableSubscriptionsAfterSelection", ThisObject, StructureAdditionalParameters);
		
	OpenForm("Catalog.SubscriptionPlans.Form.SubscriptionsRecordForm", 
		FormParameters,
		,,,,
		NotificationSelection);
	
EndProcedure

&AtClient
Procedure TableSubscriptionsAfterSelection(EditedRowResult, AdditionalParameters) Export
	
	If EditedRowResult = Undefined Then
		
		Return;
		
	Else
		
		DataRow = AdditionalParameters.Key.CurrentData;
		
		FillPropertyValues(DataRow, EditedRowResult);
		
		IsSubscriptionsChanged = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TableSubscriptionsAfterDeleteRow(Item)
	
	IsSubscriptionsChanged = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AddPeriodRepresentation(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If Not CurrentData = Undefined Then
		CurrentData.Content = CurrentData.Content + " " + PeriodRepresentationParameter;	
	EndIf;
	
EndProcedure

&AtClient
Procedure SetJobShedule(Command)
	
	If Schedule = Undefined Then
		Schedule = New JobSchedule;
	EndIf;
	
	SetNewShedule = New NotifyDescription("SetNewShedule", ThisObject);
	SheduleDialog = New ScheduledJobDialog(Schedule);
	SheduleDialog.Show(SetNewShedule);
	
EndProcedure

&AtClient
Procedure OpenCustomSchedule(Item)
	
	If Object.Ref.IsEmpty() 
		Or Not Object.Enabled Then
		
		CountLockAttributes = 0;
		
	Else 
		
		Try
		
			CountLockAttributes = ObjectAttributesLockClient.Attributes(ThisObject).Count();
		
		Except
			
			// Wrote new object, form was not closed, item AttributeEditProhibitionParameters was not created
			
			CountLockAttributes = 0;
		
		EndTry;
		
	EndIf;
	
	ParameterStructure = New Structure;
	FillCustomScheduleParameters(ParameterStructure, CountLockAttributes);
	Notification = New NotifyDescription("OnChangeCustomSchedule", ThisObject);
	OpenForm("Catalog.SubscriptionPlans.Form.CustomScheduleForm",
		ParameterStructure, 
		ThisObject, 
		UUID,,, 
		Notification, 
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure
	
&AtClient
Procedure OnChangeCustomSchedule(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult = Undefined Then
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() 
		Or Not Object.Enabled Then
		
		CountLockAttributes = 0;
		
	Else 
		
		Try
		
			CountLockAttributes = ObjectAttributesLockClient.Attributes(ThisObject).Count();
		
		Except
			
			// Wrote new object, form was not closed, item AttributeEditProhibitionParameters was not created
			
			CountLockAttributes = 0;
		
		EndTry;
		
	EndIf;
	
	If CountLockAttributes = 0
		And OpeningResult.Property("DataAddress") Then
		
		OnChangeCustomScheduleServer(OpeningResult.DataAddress);
		
	EndIf;
	
EndProcedure

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ContinuationHandler = New NotifyDescription("AllowEditingUserDefinedSchedule", ThisObject);
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject, ContinuationHandler);
	
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion 

#Region Private

#Region ManageControls

&AtServer
Procedure SetSubscriptionsFilter()
	SetFilterBySubscriptionPlan(Subscriptions, "SubscriptionPlan");
EndProcedure

&AtServer
Procedure SetDocumentsFilter()
	
	If Object.TypeOfDocument = DocumentsNameSalesInvoice() Then
		SetFilterBySubscriptionPlan(SalesInvoices, "Subscription");
	ElsIf Object.TypeOfDocument = "PurchaseOrder" Then
		SetFilterBySubscriptionPlan(PurchaseOrders, "Schedule");
	Else
		SetFilterBySubscriptionPlan(SupplierInvoice, "Schedule");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFilterBySubscriptionPlan(Item, FieldName)
	
	Item.Filter.Items.Clear();
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	FilterGroup.Use = True;
	
	Filter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	Filter.LeftValue = New DataCompositionField(FieldName);
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.RightValue = Object.Ref;
	Filter.Use = True;
	
	Filter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	Filter.LeftValue = New DataCompositionField(FieldName);
	Filter.ComparisonType = DataCompositionComparisonType.Filled;
	Filter.Use = True;	
	
EndProcedure

&AtClient
Procedure SetConditionalAppearance()
	
	IsSalesInvoices		= False;
	IsPurchaseOrders	= False;
	IsSupplierInvoice	= False;
	
	Items.TaxInvoicePrintForm.Visible = UseTaxInvoices;
	
	Description = TrimAll(Object.Description);
	
	If Object.TypeOfDocument = DocumentsNameSalesInvoice() Then
			
		Type = NStr("en = 'Subscription plan'; ru = 'План подписки';pl = 'Plan subskrypcji';es_ES = 'Plan de suscripción';es_CO = 'Plan de suscripción';tr = 'Abonelik planı';it = 'Piano di abbonamento';de = 'Abonnement-Plan'");
		
		Items.ChargeFrequency.Title = NStr("en = 'Frequency'; ru = 'Периодичность';pl = 'Okresowość';es_ES = 'Frecuencia';es_CO = 'Frecuencia';tr = 'Sıklık';it = 'Frequenza';de = 'Häufigkeit'");
		
		Items.RightColumn.Visible = True;
		Items.InventoryCharacteristic.Visible = False;
		Items.InventoryBatch.Visible = False;
		
		Items.TableSubscriptionsCounterparty.Title = NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		Items.TableSubscriptionsEmailTo.Visible = True;
		
		IsSalesInvoices = True;
		
	Else
		
		If Object.TypeOfDocument = "PurchaseOrder" Then
			
			Type = NStr("en = 'Purchase order schedule'; ru = 'График заказов поставщику';pl = 'Harmonogram zamówień zakupu';es_ES = 'Horario de la orden de compra';es_CO = 'Horario de la orden de compra';tr = 'Satın alma siparişi planı';it = 'Programma ordini di acquisto';de = 'Zeitplan für Bestellung an Lieferanten'");
			
			Items.ChargeFrequency.Title = NStr("en = 'Frequency'; ru = 'Периодичность';pl = 'Okresowość';es_ES = 'Frecuencia';es_CO = 'Frecuencia';tr = 'Sıklık';it = 'Frequenza';de = 'Häufigkeit'");
			
			IsPurchaseOrders = True;
			
		Else
			
			Type = NStr("en = 'Supplier invoice schedule'; ru = 'График инвойса поставщика';pl = 'Harmonogram faktury zakupu';es_ES = 'Horario de factura de compra';es_CO = 'Horario de factura de compra';tr = 'Satın alma faturası programı';it = 'Programma fattura di acquisto';de = 'Lieferantenrechnungszeitplan'");
			
			Items.ChargeFrequency.Title = NStr("en = 'Frequency'; ru = 'Периодичность';pl = 'Okresowość';es_ES = 'Frecuencia';es_CO = 'Frecuencia';tr = 'Sıklık';it = 'Frequenza';de = 'Häufigkeit'");
			
			IsSupplierInvoice = True;
			
		EndIf;
		
		Items.RightColumn.Visible = False;
		Items.InventoryCharacteristic.Visible = True;
		Items.InventoryBatch.Visible = True;
		
		Items.TableSubscriptionsCounterparty.Title = NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		Items.TableSubscriptionsEmailTo.Visible = False;
		
	EndIf;
	
	Items.UseTemplate.Visible		= IsSupplierInvoice;
	
	Items.SalesInvoices.Visible		= IsSalesInvoices;
	Items.PurchaseOrders.Visible	= IsPurchaseOrders;
	Items.SupplierInvoice.Visible	= IsSupplierInvoice;
	
	SetAppearanceTemplate();
	
	If Object.Ref.IsEmpty() Then
		Description = Type;
		Type = NStr("en = 'create'; ru = 'создание';pl = 'utwórz';es_ES = 'crear';es_CO = 'crear';tr = 'oluştur';it = 'creare';de = 'erstellen'");
	EndIf;
	
	Title = Description + " " + "(" + Type + ")";
		
EndProcedure

&AtClient
Procedure SetAppearanceTemplate()
	
	Items.Template.Visible	= UseTemplate;
	
	IsBlankTemplate = Not ValueIsFilled(Object.Template);
	
	Items.Inventory.Visible	= IsBlankTemplate;
	Items.Company.Visible	= IsBlankTemplate;
	
	Items.InventoryTemplate.Visible	= Not IsBlankTemplate;
	
	Items.TableSubscriptionsCommandBar.Enabled = IsBlankTemplate;
	Items.TableSubscriptionsContextMenu.Enabled = IsBlankTemplate;
	
EndProcedure

&AtClient
Procedure SetScheduleButtonTitle()
	
	If Schedule = Undefined Then
		Items.JobShedule.Title = NStr("en = 'Fill in schedule'; ru = 'Заполнить график';pl = 'Wypełnij w harmonogramie';es_ES = 'Rellene el horario';es_CO = 'Rellene el horario';tr = 'Programı doldur';it = 'Compilare programma';de = 'Zeitplan ausfüllen'");
	Else
		Items.JobShedule.Title = Left(Schedule, 50);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPagesTitles()
	
	If Object.TypeOfDocument = DocumentsNameSalesInvoice() Then
		Items.GroupSubscriptions.Title = NStr("en = 'Customers'; ru = 'Покупатели';pl = 'Nabywcy';es_ES = 'Clientes';es_CO = 'Clientes';tr = 'Müşteriler';it = 'Clienti';de = 'Kunden'");
		Items.GroupDocuments.Title = NStr("en = 'Sales invoices'; ru = 'Инвойсы покупателю';pl = 'Faktury sprzedaży';es_ES = 'Facturas de ventas';es_CO = 'Facturas de ventas';tr = 'Satış faturaları';it = 'Fatture di vendita';de = 'Verkaufsrechnungen'");
	ElsIf Object.TypeOfDocument = "PurchaseOrder" Then
		Items.GroupSubscriptions.Title = NStr("en = 'Suppliers'; ru = 'Поставщики';pl = 'Dostawcy';es_ES = 'Proveedores';es_CO = 'Proveedores';tr = 'Tedarikçiler';it = 'Fornitori';de = 'Lieferanten'");
		Items.GroupDocuments.Title = NStr("en = 'Purchase orders'; ru = 'Заказы поставщикам';pl = 'Zamówienia zakupu';es_ES = 'Órdenes de compra';es_CO = 'Órdenes de compra';tr = 'Satın alma siparişleri';it = 'Ordini di acquisto';de = 'Bestellungen an Lieferanten'");
	Else
		Items.GroupSubscriptions.Title = NStr("en = 'Suppliers'; ru = 'Поставщики';pl = 'Dostawcy';es_ES = 'Proveedores';es_CO = 'Proveedores';tr = 'Tedarikçiler';it = 'Fornitori';de = 'Lieferanten'");
		Items.GroupDocuments.Title = NStr("en = 'Supplier invoices'; ru = 'Инвойс поставщика';pl = 'Faktury zakupu';es_ES = 'Facturas de proveedor';es_CO = 'Facturas del proveedor';tr = 'Satın alma faturaları';it = 'Fatture fornitori';de = 'Lieferantenrechnungen'");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetPrintFormsChoiceList(Item, PrintFormsTable)
	
	For Each PrintForm In PrintFormsTable Do
		If IsBlankString(PrintForm.Handler) Then
			Item.ChoiceList.Add(PrintForm.UUID, PrintForm.Presentation);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetContractsVisible()
	
	Items.TableSubscriptionsContract.Visible = UseContracts;
	Items.SalesInvoicesContract.Visible = UseContracts;
	Items.PurchaseOrdersContract.Visible = UseContracts;
	
EndProcedure

&AtClient
Procedure SetVisibleCommandGroupTrigger()
	
	Items.GroupRowUserDefined.Visible = (Object.ChargeFrequency = PredefinedValue("Enum.Periodicity.Month"));
	
EndProcedure

&AtClient
Procedure SetEnabledLinkCustomSchedule()
	
	Items.LinkCustomSchedule.Enabled	= Object.UseCustomSchedule;
	Items.JobShedule.Visible			= Not Object.UseCustomSchedule;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.InventoryTemplatePrice);
	
	Return Fields;
	
EndFunction

#EndRegion

&AtServerNoContext
Function RegisterVATWithTaxInvoices(Company)
	
	If Company.IsEmpty() Then
		Return False;
	EndIf;
	
	Return WorkWithVAT.GetUseTaxInvoiceForPostingVAT(CurrentSessionDate(), Company);
	
EndFunction

&AtServer
Procedure FillPrintFormToPrintChoiceList()
	
	SetPrintFormsChoiceList(
		Items.SalesInvoicePrintForm, 
		PrintManagement.FormPrintCommands("Document.SalesInvoice.Form.DocumentForm"));
	
	SetPrintFormsChoiceList(
		Items.TaxInvoicePrintForm,
		PrintManagement.FormPrintCommands("Document.TaxInvoiceIssued.Form.DocumentForm"));
	
EndProcedure

&AtClient
Procedure SetNewShedule(NewSchedule, AdditionalParameters) Export
	
	If NewSchedule = Undefined Then
		Return;
	EndIf;
	
	Schedule = NewSchedule;
	Modified = True;
	SetScheduleButtonTitle();	
	
EndProcedure

&AtClient
Procedure BeforeDeleteRemovalProducts(Result, StructureData) Export

	If Result = DialogReturnCode.Yes Then
		
		For Each RemovalProduct In StructureData.RemovalProducts Do
			
			RowsArray = Object.Inventory.FindRows(New Structure("Products", RemovalProduct));
			For Index = 1 - RowsArray.Count() To 0 Do
				RowIndex = Object.Inventory.IndexOf(RowsArray[-Index]);
				Object.Inventory.Delete(RowIndex);
			EndDo;
			
		EndDo;
		
		ProcessingInventoryStructureData(StructureData);
		
		SetDocumentsFilter();
		SetPagesTitles();
		SetConditionalAppearance();
		
	Else
		Object.TypeOfDocument = DocumentsNamePurchaseOrder();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	StructureData.Insert("Quantity", 1);
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetInventoryStructureData()
	
	StructureData = New Structure;
	
	StructureData.Insert("UseTaxInvoices", TaxInvoicesAreUsed(Object.TypeOfDocument, Object.Company));
	StructureData.Insert("RemovalProducts", GetRemovalProducts(Object.TypeOfDocument, Object.Inventory.Unload()));
	StructureData.Insert("ProductsChoiceParameters", GetProductsChoiceParameters());
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetTableSubscriptions()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Subscriptions.Counterparty AS Counterparty,
	|	Subscriptions.Contract AS Contract,
	|	Subscriptions.EmailTo AS EmailTo,
	|	Subscriptions.StartDate AS StartDate,
	|	Subscriptions.EndDate AS EndDate
	|FROM
	|	InformationRegister.Subscriptions AS Subscriptions
	|WHERE
	|	Subscriptions.SubscriptionPlan = &SubscriptionPlan";
	
	Query.SetParameter("SubscriptionPlan", Object.Ref);
	
	TableResult = Query.Execute().Unload();
	
	Return TableResult;
	
EndFunction

&AtClient
Procedure ProcessingInventoryStructureData(StructureData)
	
	UseTaxInvoices = StructureData.UseTaxInvoices;
	Items.InventoryProducts.ChoiceParameters = StructureData.ProductsChoiceParameters; 
	
EndProcedure

&AtClient
Procedure OpenDocument(Ref, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("Document." + Object.TypeOfDocument + ".ObjectForm", 
		New Structure("Key, ReadOnly", Ref, False));	
	
EndProcedure

&AtServerNoContext
Function CheckCompanyChangePossibility(SubscriptionPlan, Company)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	CounterpartyContracts.Company AS Company
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|		INNER JOIN InformationRegister.Subscriptions AS Subscriptions
	|		ON CounterpartyContracts.Ref = Subscriptions.Contract
	|WHERE
	|	CounterpartyContracts.Company <> &Company
	|	AND Subscriptions.SubscriptionPlan = &SubscriptionPlan
	|	AND Subscriptions.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)";
	
	Query.SetParameter("SubscriptionPlan", SubscriptionPlan);
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return True;
	EndIf;
	
	ContractsSelection = QueryResult.Select();
	ContractsSelection.Next();
	
	Company = ContractsSelection.Company;
	
	Return False;
	
EndFunction

&AtClientAtServerNoContext
Function TaxInvoicesAreUsed(TypeOfDocument, Company)
	
	Return (TypeOfDocument = DocumentsNameSalesInvoice())
		And RegisterVATWithTaxInvoices(Company);
	
EndFunction

&AtServer
Function GetRemovalProducts(TypeOfDocument, Inventory)
	
	RemovalProducts = New Array;
	
	Query = New Query;
	
	If TypeOfDocument = "SupplierInvoice"
		Or TypeOfDocument = "PurchaseOrder" Then
	
		Query.Text =
		"SELECT
		|	CAST(Inventory.Products AS Catalog.Products) AS Products
		|INTO TT_Inventory
		|FROM
		|	&Inventory AS Inventory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_Inventory.Products AS Products
		|FROM
		|	TT_Inventory AS TT_Inventory
		|WHERE
		|	TT_Inventory.Products.ProductsType = VALUE(Enum.ProductsTypes.Work)";	
	
	ElsIf TypeOfDocument = "SalesInvoice" Then
		
		Query.Text =
		"SELECT
		|	CAST(Inventory.Products AS Catalog.Products) AS Products
		|INTO TT_Inventory
		|FROM
		|	&Inventory AS Inventory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_Inventory.Products AS Products
		|FROM
		|	TT_Inventory AS TT_Inventory
		|WHERE
		|	TT_Inventory.Products.ProductsType <> VALUE(Enum.ProductsTypes.Service)";
		
	EndIf;
	
	Query.SetParameter("Inventory", Inventory);
	
	ProductsTable = Query.Execute().Unload();
	RemovalProducts = ProductsTable.UnloadColumn("Products");
	
	Return RemovalProducts;
	
EndFunction

&AtServer
Function GetProductsChoiceParameters()
	
	ChoiceParametersArray = New Array;
	
	If Object.TypeOfDocument = DocumentsNameSalesInvoice() Then
		
		ChoiceParametersArray.Add(New ChoiceParameter("Filter.ProductsType", Enums.ProductsTypes.Service));
	
	Else 
		
		BaseArray = New Array();
		BaseArray.Add(Enums.ProductsTypes.InventoryItem);
		BaseArray.Add(Enums.ProductsTypes.Service);
		ArrayInventoryAndServices = New FixedArray(BaseArray);
		
		ChoiceParameterFilter			= New ChoiceParameter("Filter.ProductsType", ArrayInventoryAndServices);
		ChoiceParameterTypeRestriction	= New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryAndServices);
		
		ChoiceParametersArray.Add(ChoiceParameterFilter);
		ChoiceParametersArray.Add(ChoiceParameterTypeRestriction);
		
	EndIf;
	
	Return New FixedArray(ChoiceParametersArray);
	
EndFunction

&AtClientAtServerNoContext
Function DocumentsNameSalesInvoice()
	Return "SalesInvoice";
EndFunction

&AtClientAtServerNoContext
Function DocumentsNamePurchaseOrder()
	Return "PurchaseOrder";
EndFunction

&AtServer
Procedure SetCompanyAndCounterpartyFromTemplate()
	
	StructureTemplate = Common.ObjectAttributesValues(Object.Template, "Company, Counterparty, Contract");
	
	Object.Company = StructureTemplate.Company;
	
	TableSubscriptions.Clear();
	
	NewLineSubscription = TableSubscriptions.Add();
	
	NewLineSubscription.Counterparty	= StructureTemplate.Counterparty;
	NewLineSubscription.Contract		= StructureTemplate.Contract;
	
EndProcedure

&AtServer
Procedure SetSubscriptionForTemplate()
	
	Records = InformationRegisters.Subscriptions.CreateRecordSet();
	
	Records.Filter.SubscriptionPlan.Set(Object.Ref);
	
	Records.Write();
	
	StringAttributes = "Counterparty";
	
	If UseContracts Then
		StringAttributes = StringAttributes + ", Contract";
	EndIf;
	
	
	StructureTemplate = Common.ObjectAttributesValues(Object.Template, StringAttributes);
	
	NewRecord = Records.Add();
	
	NewRecord.SubscriptionPlan	= Object.Ref;
	NewRecord.Counterparty		= StructureTemplate.Counterparty;
	If UseContracts Then
		NewRecord.Contract		= StructureTemplate.Contract;
	EndIf;
	
	If Object.UseCustomSchedule
		And ValueIsFilled(Object.UserDefinedStartDate) Then
		NewRecord.StartDate		= Object.UserDefinedStartDate;
	EndIf;
	
	If Object.UseCustomSchedule
		And ValueIsFilled(Object.UserDefinedEndDate) Then
		NewRecord.EndDate		= Object.UserDefinedEndDate;
	EndIf;
	
	Records.Write();
	
EndProcedure

&AtServer
Procedure FillValueTableUserDefinedSchedule(CheckDocumentsGenerated = False)
	
	UserDefinedSchedule.Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	GeneratedDocumentsData.PlannedDate AS PlannedDate
	|FROM
	|	InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
	|WHERE
	|	GeneratedDocumentsData.SubscriptionPlan = &SubscriptionPlan";
	
	Query.SetParameter("SubscriptionPlan", Object.Ref);
	
	QueryResult = Query.Execute();
	
	UserDefinedSchedule.Load(QueryResult.Unload());
	
	If CheckDocumentsGenerated Then
		
		Query.Text = 
		"SELECT ALLOWED
		|	GeneratedDocumentsData.PlannedDate AS PlannedDate
		|FROM
		|	InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
		|WHERE
		|	GeneratedDocumentsData.SubscriptionPlan = &SubscriptionPlan
		|	AND GeneratedDocumentsData.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)";
		
		QueryResult = Query.Execute();
		
		IsDocumentsGenerated = Not QueryResult.IsEmpty();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AddValueUserDefinedSchedule(NewValuePlannedDate, RefObject)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	GeneratedDocumentsData.SubscriptionPlan AS SubscriptionPlan,
	|	GeneratedDocumentsData.PlannedDate AS PlannedDate
	|FROM
	|	InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
	|WHERE
	|	GeneratedDocumentsData.SubscriptionPlan = &SubscriptionPlan
	|	AND GeneratedDocumentsData.PlannedDate = &PlannedDate";
	
	Query.SetParameter("PlannedDate", NewValuePlannedDate);
	Query.SetParameter("SubscriptionPlan", RefObject);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordManagerSchedule = InformationRegisters.GeneratedDocumentsData.CreateRecordManager();
	
	RecordManagerSchedule.PlannedDate		= NewValuePlannedDate;
	RecordManagerSchedule.SubscriptionPlan	= RefObject;
	RecordManagerSchedule.ActualDate		= Date(1, 1, 1);
	RecordManagerSchedule.Counterparty		= Catalogs.Counterparties.EmptyRef();
	
	RecordManagerSchedule.Write();
	
EndProcedure

&AtServer
Procedure DeleteValueUserDefinedSchedule(PlannedDate, RefObject)
	
	RecordSetSchedule = InformationRegisters.GeneratedDocumentsData.CreateRecordSet();
	
	RecordSetSchedule.Filter.SubscriptionPlan.Set(RefObject);
	RecordSetSchedule.Filter.PlannedDate.Set(PlannedDate);
	
	RecordSetSchedule.Write();
	
EndProcedure

&AtClient
Procedure AllowEditingUserDefinedSchedule(Result, UserDefinedParameters) Export
	
	If Result Then
		
		IsLockAttributes = False;
	
		Items.JobShedule.Enabled			= True;
		Items.UseTemplate.Enabled			= True;
		Items.TableSubscriptions.ReadOnly	= False;
		
		Modified = False;
		
		SetEnabledProductsGroupAddParameter();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInventoryTemplate()
	
	InventoryTemplate.Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SupplierInvoiceInventory.Price AS Price
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoiceExpenses.Products,
	|	NULL,
	|	SupplierInvoiceExpenses.Quantity,
	|	SupplierInvoiceExpenses.MeasurementUnit,
	|	SupplierInvoiceExpenses.Price
	|FROM
	|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
	|WHERE
	|	SupplierInvoiceExpenses.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Template);
	
	InventoryTemplate.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure CheckScheduleBeforeWriteAtServer(Cancel, ArrayMessages)
	
	If Not Object.Enabled Then
		
		Return;
		
	EndIf;
	
	If Object.UseCustomSchedule Then
		
		If Not ValueIsFilled(Object.UserDefinedStartDate)
			Or Not ValueIsFilled(Object.UserDefinedStartDate) Then
			
			
			
			TextMessage = NStr("en = 'Period is required in the Custom schedule window.
				|Ensure that you specify both start date and end date for this period.'; 
				|ru = 'В окне Пользовательский график требуется указать период.
				|Убедитесь, что для этого периода указаны как дата начала, так и дата окончания.';
				|pl = 'Okres jest wymagany w oknie Niestandardowy harmonogram.
				|Upewnij się, że określono zarówno datę rozpoczęcia, jak i datę zakończenia dla tego okresu.';
				|es_ES = 'El período es necesario en la ventana de horario personalizado.
				|Asegúrese de especificar tanto la fecha de inicio como la fecha de terminación de este período.';
				|es_CO = 'El período es necesario en la ventana de horario personalizado.
				|Asegúrese de especificar tanto la fecha de inicio como la fecha de terminación de este período.';
				|tr = 'Özel program penceresinde dönem gerekli.
				|Bu dönemin başlangıç tarihi ile bitiş tarihinin belirtildiğinden emin olun.';
				|it = 'Il Periodo è richiesto nella finestra Programma personalizzato. 
				|Assicurarsi di aver specificato sia data di inizio che di fine per questo periodo.';
				|de = 'Zeitraum ist im Fenster Benutzerdefinierter Zeitplan erforderlich.
				|Stellen Sie sicher, dass Sie sowohl das Start- als auch das Enddatum für diesen Zeitraum angeben.'");
				
			StructureMessage = New Structure("TextMessage", "FieldForm");
			
			StructureMessage.Insert("TextMessage", TextMessage);
			StructureMessage.Insert("FieldForm", "MessageCustomSchedule");
			
			ArrayMessages.Add(StructureMessage);
			
			Cancel = True;
			
		EndIf;
		
	Else  
		
		If Schedule = Undefined Then
			
			
			
			TextMessage = NStr("en = 'A schedule is required. Click ""Fill in schedule"" and specify the schedule details.'; ru = 'Требуется график. Нажмите ""Заполнить график"" и укажите описание графика.';pl = 'Wymagany jest harmonogram. Kliknij ""Wypełnij w harmonogramie"" i określ szczegóły harmonogramu.';es_ES = 'Se requiere un horario. Haga clic en ""Rellenar el horario"" y especifique los detalles del horario.';es_CO = 'Se requiere un horario. Haga clic en ""Rellenar el horario"" y especifique los detalles del horario.';tr = 'Program gerekli. ""Programı doldur""a tıklayın ve program ayrıntılarını girin.';it = 'È richiesto un programma. Cliccare su ""Compilare programma"" e specificare i dettagli del programma.';de = 'Ein Zeitplan ist erforderlich. Klicken Sie auf „Zeitplan ausfüllen“ und geben Sie die Zeitplandetails an.'");
			
			StructureMessage = New Structure("TextMessage", "FieldForm");
			
			StructureMessage.Insert("TextMessage", TextMessage);
			StructureMessage.Insert("FieldForm", "MessageJobSchedule");
			
			ArrayMessages.Add(StructureMessage);
			
			Cancel = True;
			
			Return;
		
		EndIf;
		
		If TableSubscriptions.Count() = 0 Then
			
			If Parameters.PurchaseDocumentsSchedule Then
				TextMessage = NStr("en = 'Suppliers are required on the Suppliers tab.'; ru = 'Укажите поставщиков на вкладке ""Поставщики"".';pl = 'Dostawcy są wymagane na karcie Dostawcy.';es_ES = 'Los Proveedores se requieren en la pestaña Proveedores.';es_CO = 'Los Proveedores se requieren en la pestaña Proveedores.';tr = 'Tedarikçiler sekmesinde tedarikçiler gerekli.';it = 'Sono richiesti i Fornitori nella scheda Fornitori.';de = 'Lieferanten ist ein Pflichtfeld auf der Registerkarte Lieferanten.'");
			Else
				TextMessage = NStr("en = 'Customers are required on the Customers tab.'; ru = 'Укажите покупателей на вкладке ""Покупатели"".';pl = 'Nabywcy są wymagane na karcie Nabywcy.';es_ES = 'Los Clientes se requieren en la pestaña de Clientes.';es_CO = 'Los Clientes se requieren en la pestaña de Clientes.';tr = 'Müşteriler sekmesinde müşteriler gerekli.';it = 'Sono richiesti i Clienti nella scheda Clienti.';de = 'Kunden ist ein Pflichtfeld auf der Registerkarte Kunden.'");
			EndIf;
			
			StructureMessage = New Structure("TextMessage", "FieldForm");
			
			StructureMessage.Insert("TextMessage", TextMessage);
			StructureMessage.Insert("FieldForm", "TableSubscriptions");
			
			ArrayMessages.Add(StructureMessage);
			
			Cancel = True;
			
		Else 
		
			DateStartPlan	= Date(1, 1, 1);
			
			For Each LineRecord In TableSubscriptions Do
				
				If DateStartPlan < LineRecord.StartDate Then
					
					DateStartPlan = LineRecord.StartDate;
					
				EndIf;
				
			EndDo;
			
			If DateStartPlan = Date(1, 1, 1) Then
				
				If Parameters.PurchaseDocumentsSchedule Then
					TextMessage = NStr("en = 'Start date is required for each schedule on the Suppliers tab.'; ru = 'Для каждого графика на вкладке ""Поставщики"" требуется указать дату начала.';pl = 'Wymagana jest data rozpoczęcia dla każdego harmonogramu na karcie Dostawcy.';es_ES = 'La fecha de inicio se requiere para cada horario en la pestaña Proveedores.';es_CO = 'La fecha de inicio se requiere para cada horario en la pestaña Proveedores.';tr = 'Tedarikçiler sekmesinde her program için başlangıç tarihi gerekli.';it = 'La data di inizio è richiesta per ciascun grafico nella scheda Fornitori.';de = 'Startdatum ist für jeden Zeitplan auf der Registerkarte Lieferanten erforderlich.'");
				Else
					TextMessage = NStr("en = 'Start date is required for each schedule on the Customers tab.'; ru = 'Для каждого графика на вкладке ""Покупатели"" требуется указать дату начала.';pl = 'Wymagana jest data rozpoczęcia dla każdego harmonogramu na karcie Nabywcy.';es_ES = 'La fecha de inicio se requiere para cada horario en la pestaña Clientes.';es_CO = 'La fecha de inicio se requiere para cada horario en la pestaña Clientes.';tr = 'Müşteriler sekmesinde her program için başlangıç tarihi gerekli.';it = 'La data di inizio è richiesta per ciascun grafico nella scheda Clienti.';de = 'Startdatum ist für jeden Zeitplan auf der Registerkarte Kunden erforderlich.'");
				EndIf;
				
				StructureMessage = New Structure("TextMessage", "FieldForm");
				
				StructureMessage.Insert("TextMessage", TextMessage);
				StructureMessage.Insert("FieldForm", "TableSubscriptions");
				
				ArrayMessages.Add(StructureMessage);
				
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetCurrentSessionDate()
	Return CurrentSessionDate();
EndFunction

&AtServer
Procedure FillCustomScheduleParameters(ParameterStructure, CountLockAttributes)
	
	DataStructure = New Structure;
	
	IsReadOnly = (Object.Enabled And CountLockAttributes > 0);
		
	DataStructure.Insert("ReadOnly",		IsReadOnly);
	
	DataStructure.Insert("UserDefinedStartDate",		Object.UserDefinedStartDate);
	DataStructure.Insert("UserDefinedEndDate",			Object.UserDefinedEndDate);
	DataStructure.Insert("UserDefinedBusinessCalendar",	Object.UserDefinedBusinessCalendar);
	DataStructure.Insert("UserDefinedDateType",			Object.UserDefinedDateType);
	DataStructure.Insert("UserDefinedDayOf",			Object.UserDefinedDayOf);
	DataStructure.Insert("UserDefinedCalculateFrom",	Object.UserDefinedCalculateFrom);
	DataStructure.Insert("UserDefinedSchedule",			UserDefinedSchedule.Unload());
	
	DataStructure.Insert("IsDocumentsGenerated",		IsDocumentsGenerated);
	
	If Not ReadOnly
		And CompareUserDefinedSchedule.Count() = 0 Then
		
		CompareUserDefinedSchedule.Load(UserDefinedSchedule.Unload());
		
	EndIf;
	
	ParameterStructure.Insert("DataAddress", PutToTempStorage(DataStructure, UUID));
	
EndProcedure

&AtServer
Procedure OnChangeCustomScheduleServer(StringAddress);
	
	If Not IsTempStorageURL(StringAddress) Then
		Return;
	EndIf;
	
	Modified = True;
	
	DataStructure = GetFromTempStorage(StringAddress);
	
	FillPropertyValues(Object, DataStructure);
	
	IsCustomScheduleChanged = DataStructure.IsCustomScheduleChanged;
	
	UserDefinedSchedule.Load(DataStructure.UserDefinedSchedule);
	
EndProcedure

&AtClient
Procedure SetEnabledProductsGroupAddParameter()
	
	If IsLockAttributes
		And Object.Enabled
		And ObjectAttributesLockClient.Attributes(ThisObject).Count() > 0 Then
		
		Items.ProductsGroupAddParameter.Enabled = False;
		
		Return;
		
	EndIf;
	
	Items.ProductsGroupAddParameter.Enabled = (Object.Inventory.Count() <> 0);
	
EndProcedure

&AtServer
Procedure SetRecordsSubscriptions(RefObject)
	
	RecordSetSubscriptions = InformationRegisters.Subscriptions.CreateRecordSet();
	
	RecordSetSubscriptions.Filter.SubscriptionPlan.Set(RefObject);
	
	RecordSetSubscriptions.Write();
	
	For Each LineSubscription In TableSubscriptions Do
	
		RecordManagerSubscriptions = InformationRegisters.Subscriptions.CreateRecordManager();
		
		FillPropertyValues(RecordManagerSubscriptions, LineSubscription);
		
		RecordManagerSubscriptions.SubscriptionPlan = RefObject;
		
		RecordManagerSubscriptions.Write();
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillTypeOfDocumentChoiceList(PurchaseDocumentsSchedule)

	If PurchaseDocumentsSchedule Then
		Items.TypeOfDocument.ChoiceList.Add("PurchaseOrder", NStr("en = 'Purchase order'; ru = 'Заказ поставщику';pl = 'Zamówienie zakupu';es_ES = 'Orden de compra';es_CO = 'Orden de compra';tr = 'Satın alma siparişi';it = 'Ordine di acquisto';de = 'Bestellung an Lieferanten'"));
		Items.TypeOfDocument.ChoiceList.Add("SupplierInvoice", NStr("en = 'Supplier invoice'; ru = 'Инвойс поставщика';pl = 'Faktura zakupu';es_ES = 'Factura de compra';es_CO = 'Factura de compra';tr = 'Satın alma faturası';it = 'Fattura di acquisto';de = 'Lieferantenrechnung'"));
	Else
		Items.TypeOfDocument.ChoiceList.Add("SalesInvoice", NStr("en = 'Sales invoice'; ru = 'Инвойс покупателю';pl = 'Faktura sprzedaży';es_ES = 'Factura de ventas';es_CO = 'Factura de ventas';tr = 'Satış faturası';it = 'Fattura di vendita';de = 'Verkaufsrechnung'"));
	EndIf;

EndProcedure

#EndRegion 