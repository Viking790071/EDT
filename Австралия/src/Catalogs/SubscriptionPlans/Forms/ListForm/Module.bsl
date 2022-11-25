
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("PurchaseDocumentsSchedule")
		And Parameters.PurchaseDocumentsSchedule = True Then
		
		PurchaseDocumentsSchedule = True;
		
	EndIf;
	
	SetConditionalAppearance();
	SetTypeOfDocumentFilter();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
		
	FormParameters = New Structure;
	FormParameters.Insert("PurchaseDocumentsSchedule", PurchaseDocumentsSchedule);
	
	If Clone Then
		
		CurrentData = Items.List.CurrentData;
		If Not CurrentData = Undefined Then
			FormParameters.Insert("CopyingValue", CurrentData.Ref);
		EndIf;
		
	EndIf;	
	
	OpenForm("Catalog.SubscriptionPlans.ObjectForm", FormParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Enabled");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	
	If PurchaseDocumentsSchedule Then
		
		ThisObject.Title = NStr("en = 'Recurring purchases'; ru = 'Регулярные закупки';pl = 'Zakup cykliczny';es_ES = 'Compras recurrentes';es_CO = 'Compras recurrentes';tr = 'Tekrarlayan satın alımlar';it = 'Acquisto ricorrente';de = 'Wiederkehrende Einkäufe'");
		
		Items.ChargeFrequency.Title = NStr("en = 'Frequency'; ru = 'Периодичность';pl = 'Okresowość';es_ES = 'Frecuencia';es_CO = 'Frecuencia';tr = 'Sıklık';it = 'Frequenza';de = 'Häufigkeit'");
		
		Items.ActionOnCreating.Visible = False;
		Items.EmailAccount.Visible = False;
		Items.EmailSubject.Visible = False;
		
	Else
		
		ThisObject.Title = NStr("en = 'Subscription plans'; ru = 'Планы подписок';pl = 'Plany subskrypcji';es_ES = 'Planes de suscripción';es_CO = 'Planes de suscripción';tr = 'Abonelik planları';it = 'Piano di abbonamento';de = 'Abonnement-Pläne'");
		
		Items.ChargeFrequency.Title = NStr("en = 'Charge frequency'; ru = 'Период оплаты';pl = 'Częstotliwość obciążenia';es_ES = 'Frecuencia de carga';es_CO = 'Frecuencia de carga';tr = 'Yükleme sıklığı';it = 'Frequenza pagamento';de = 'Ladefrequenz'");
		
		Items.ActionOnCreating.Visible = True;
		Items.EmailAccount.Visible = True;
		Items.EmailSubject.Visible = True;
		
	EndIf;
		
EndProcedure

&AtServer
Procedure SetTypeOfDocumentFilter()
	
	List.Filter.Items.Clear();
	
	Filter = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.LeftValue = New DataCompositionField("TypeOfDocument");
	
	If PurchaseDocumentsSchedule Then
		
		ListDocs = New ValueList;
		ListDocs.Add("PurchaseOrder");
		ListDocs.Add("SupplierInvoice");
		
		Filter.ComparisonType	= DataCompositionComparisonType.InList;
		Filter.RightValue		= ListDocs;
		Filter.Use				= True;
		
	Else
		
		Filter.ComparisonType	= DataCompositionComparisonType.Equal;
		Filter.RightValue		= "SalesInvoice";
		Filter.Use				= True;
		
	EndIf;
	
EndProcedure

&AtServer
Function GetListSubscriptionPlans()
	
	Result = New ValueList;
	
	ListTypesOfDocument = New ValueList;
	
	If PurchaseDocumentsSchedule Then
		
		ListTypesOfDocument.Add("PurchaseOrder");
		ListTypesOfDocument.Add("SupplierInvoice");
		
	Else 
		
		ListTypesOfDocument.Add("SalesInvoice");
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SubscriptionPlans.Ref AS Ref
	|FROM
	|	Catalog.SubscriptionPlans AS SubscriptionPlans
	|WHERE
	|	SubscriptionPlans.TypeOfDocument IN(&ListTypesOfDocument)
	|	AND SubscriptionPlans.Enabled";
	
	Query.SetParameter("ListTypesOfDocument", ListTypesOfDocument);
	
	Result.LoadValues(Query.Execute().Unload().UnloadColumn("Ref"));
	
	Return Result;
	
EndFunction

&AtClient
Procedure GeneratedDocumentsSummary(Command)
	
	FormParameters = New Structure;
	
	FormParameters.Insert("PurposeUseKey", "SummaryOfGeneratedDocumentsBySubscriptionPlan");
	FormParameters.Insert("VariantKey", ?(PurchaseDocumentsSchedule, "Supplier", "Customer"));
	
	StructureFilter = New Structure("SubscriptionPlan", GetListSubscriptionPlans());
	
	FormParameters.Insert("Filter", StructureFilter);
		
	OpenForm("Report.SummaryOfGeneratedDocuments.Form", FormParameters);
	
EndProcedure

#EndRegion
