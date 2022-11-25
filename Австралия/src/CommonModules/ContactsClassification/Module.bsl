
#Region ObjectForm

// Procedure creates items of tags display in the form of the object
//
// Parameters:
//  Form	 - 	 - 
Procedure UpdateTagsCloud(Form) Export
	
	Items = Form.Items;
	Object = Form.Object;
	
	ToDeleteArray = New Array;
	For Each ItemTag In Items.TagCloud.ChildItems Do
		If Left(ItemTag.Name, 12) = "StringTags_" AND Not ItemTag.Name = "StringTags_1" Then
			ToDeleteArray.Add(ItemTag);
		EndIf;
	EndDo;
	For Each ItemTag In Items.StringTags_1.ChildItems Do
		If Left(ItemTag.Name, 4) = "Tag_" Then
			ToDeleteArray.Add(ItemTag);
		EndIf;
	EndDo;
	For Each ItemTag In ToDeleteArray Do
		Items.Delete(ItemTag);
	EndDo;
	
	FirstStringMaxLength = 61;
	MaxStringLength = FirstStringMaxLength + 24;
	ItemNumber = 0;
	ItemsStringNumber = 1;
	CurrentStringLength = 0;
	TagsGroup = Items.StringTags_1;
	
	For Each StringTags In Object.Tags Do
		
		ItemNumber = ItemNumber + 1;
		TagPresentation = String(StringTags.Tag);
		If StrLen(TagPresentation) > 15 Then
			TagPresentation = Left(TagPresentation, 15) + "...";
			TagLength = 15 + 1;
		Else
			TagLength = StrLen(TagPresentation) + 2;
		EndIf;
		
		CurrentStringLength = CurrentStringLength + TagLength;
		
		If (ItemsStringNumber = 1 AND CurrentStringLength > FirstStringMaxLength) Or (ItemsStringNumber > 1 AND CurrentStringLength > MaxStringLength) Then
			
			CurrentStringLength = TagLength;
			ItemsStringNumber = ItemsStringNumber + 1;
			
			TagsGroup = Items.Add("StringTags_" + ItemsStringNumber, Type("FormGroup"), ?(ItemsStringNumber = 1, Items.FirstRow, Items.TagCloud));
			TagsGroup.Type = FormGroupType.UsualGroup;
			TagsGroup.Group = ChildFormItemsGroup.Horizontal;
			TagsGroup.ShowTitle = False;
			TagsGroup.Representation = UsualGroupRepresentation.None;
			TagsGroup.VerticalStretch = False;
			TagsGroup.Height = 1;
			
		EndIf;
		
		TagComponents = New Array;
		TagComponents.Add(New FormattedString(TagPresentation + " "));
		TagComponents.Add(New FormattedString(PictureLib.Clear, , , , "TagID_" + StringTags.GetID()));
		
		ItemTag = Items.Add("Tag_" + ItemNumber, Type("FormDecoration"), TagsGroup);
		ItemTag.Type = FormDecorationType.Label;
		ItemTag.Title = New FormattedString(TagComponents);
		ItemTag.ToolTip = String(StringTags.Tag);
		ItemTag.BackColor = StyleColors.FormBackColor;
		ItemTag.Border = New Border(ControlBorderType.Single, 1);
		ItemTag.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemTag.Width = StrLen(TagPresentation) + 2;
		ItemTag.SetAction("URLProcessing", "Attachable_TagURLProcessing");
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ListForm

// Procedure creates form items for filtering by periods
//
// Parameters:
//  Form	 - list form
Procedure RefreshPeriodsFilterValues(Form) Export
	
	Items = Form.Items;
	Form.FilterCreated.Clear();
	
	SessionDate = CurrentSessionDate();
	
	PeriodArbitrary = Form.FilterCreated.Add();
	
	PeriodToday = Form.FilterCreated.Add();
	PeriodToday.Value.Variant = StandardPeriodVariant.Today;
	
	Period3Days = Form.FilterCreated.Add();
	Period3Days.Value.StartDate = BegOfDay(SessionDate) - 2*24*3600;
	Period3Days.Value.EndDate = EndOfDay(SessionDate);
	
	WeekPeriod = Form.FilterCreated.Add();
	WeekPeriod.Value.Variant = StandardPeriodVariant.Last7Days;
	
	MonthPeriod = Form.FilterCreated.Add();
	MonthPeriod.Value.Variant = StandardPeriodVariant.Month;
	
EndProcedure

// Procedure creates item forms for filtering by tags
//
// Parameters:
//  Form					 - list
//  form MaxStringLength	 - Number - maximum number of characters which fit in one string
Procedure RefreshTagFilterValues(Form, MaxStringLength = 85) Export
	
	Items = Form.Items;
	Form.FilterTags.Clear();
	
	DeletedItemsArray = New Array;
	For Each Item In Items.FilterValuesTags.ChildItems Do
		If Left(Item.Name, 4) = "Tag_" Or Left(Item.Name, 11) = "StringTags" Then
			DeletedItemsArray.Add(Item);
		EndIf;
	EndDo;
	For Each Item In DeletedItemsArray Do
		Items.Delete(Item);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Tags.Ref,
		|	Tags.Presentation AS Presentation
		|FROM
		|	Catalog.Tags AS Tags
		|WHERE
		|	Tags.DeletionMark = FALSE
		|
		|ORDER BY
		|	Presentation";
	
	Selection = Query.Execute().Select();
	
	ItemNumber = 0;
	ItemsStringNumber = 0;
	CurrentStringLength = 0;
	
	While Selection.Next() Do
		
		If StrLen(Selection.Presentation) > 15 Then
			TagPresentation = Left(Selection.Presentation, 15) + "...";
			CurrentStringLength = CurrentStringLength + 15 + 2;
		Else
			TagPresentation = Selection.Presentation;
			CurrentStringLength = CurrentStringLength + StrLen(TagPresentation) + 2;
		EndIf;
		
		StringTagsFilter = Form.FilterTags.Add(Selection.Ref, TagPresentation);
		
		If ItemsStringNumber = 0 Or CurrentStringLength > MaxStringLength Then
			
			CurrentStringLength = StrLen(TagPresentation) + 2;
			ItemsStringNumber = ItemsStringNumber + 1;
			
			TagsGroup = Items.Add("StringTags" + ItemsStringNumber, Type("FormGroup"), Items.FilterValuesTags);
			TagsGroup.Type = FormGroupType.UsualGroup;
			TagsGroup.Group = ChildFormItemsGroup.Horizontal;
			TagsGroup.ShowTitle = False;
			TagsGroup.Representation = UsualGroupRepresentation.None;
			TagsGroup.VerticalStretch = False;
			TagsGroup.Height = 1;
			
		EndIf;
		
		ItemTag = Items.Add("Tag_" + StringTagsFilter.GetID(), Type("FormField"), TagsGroup);
		ItemTag.Type = FormFieldType.LabelField;
		ItemTag.DataPath = "FilterTags[" + ItemNumber + "].Presentation";
		ItemTag.Hyperlink = True;
		ItemTag.TitleLocation = FormItemTitleLocation.None;
		ItemTag.ToolTip = Selection.Presentation;
		ItemTag.TextColor = StyleColors.FieldTextColor;
		ItemTag.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemTag.Width = StrLen(TagPresentation);
		ItemTag.HorizontalStretch = False;
		ItemTag.SetAction("Click", "Attachable_TagFilterClick");
		
		ItemNumber = ItemNumber + 1;
		
	EndDo;
	
	If Selection.Count() = 0 Then
		
		ItemExplanation = Items.Add("Tag_Explanation", Type("FormDecoration"), Items.FilterValuesTags);
		ItemExplanation.Type = FormDecorationType.Label;
		ItemExplanation.Hyperlink = True;
		ItemExplanation.Title = "How to work with tags?";
		ItemExplanation.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemExplanation.SetAction("Click", "Attachable_TagFilterClick");
		
	EndIf;
	
EndProcedure

// Procedure creates form items for filtering by segments
//
// Parameters:
//  Form	 - list
//  form MaxStringLength	 - Number - maximum number of characters which fit in one string
Procedure RefreshSegmentsFilterValues(Form, MaxStringLength = 85) Export
	
	Items = Form.Items;
	Form.FilterSegments.Clear();
	
	DeletedItemsArray = New Array;
	For Each Item In Items.FilterValuesSegments.ChildItems Do
		If Left(Item.Name, 8) = "Segment_" Or Left(Item.Name, 15) = "SegmentsString" Then
			DeletedItemsArray.Add(Item);
		EndIf;
	EndDo;
	For Each Item In DeletedItemsArray Do
		Items.Delete(Item);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CounterpartySegments.Ref,
		|	CounterpartySegments.Presentation AS Presentation
		|FROM
		|	Catalog.CounterpartySegments AS CounterpartySegments
		|WHERE
		|	CounterpartySegments.DeletionMark = FALSE
		|	AND CounterpartySegments.IsFolder = FALSE
		|
		|ORDER BY
		|	Presentation";
	
	Selection = Query.Execute().Select();
	
	ItemNumber = 0;
	ItemsStringNumber = 0;
	CurrentStringLength = 0;
	
	While Selection.Next() Do
		
		If StrLen(Selection.Presentation) > 15 Then
			SegmentPresentation = Left(Selection.Presentation, 15) + "...";
			CurrentStringLength = CurrentStringLength + 15 + 2;
		Else
			SegmentPresentation = Selection.Presentation;
			CurrentStringLength = CurrentStringLength + StrLen(SegmentPresentation) + 2;
		EndIf;
		
		SegmentsFilterString = Form.FilterSegments.Add(Selection.Ref, SegmentPresentation);
		
		If ItemsStringNumber = 0 Or CurrentStringLength > MaxStringLength Then
			
			CurrentStringLength = StrLen(SegmentPresentation) + 2;
			ItemsStringNumber = ItemsStringNumber + 1;
			
			SegmentsGroup = Items.Add("SegmentsString" + ItemsStringNumber, Type("FormGroup"), Items.FilterValuesSegments);
			SegmentsGroup.Type = FormGroupType.UsualGroup;
			SegmentsGroup.Group = ChildFormItemsGroup.Horizontal;
			SegmentsGroup.ShowTitle = False;
			SegmentsGroup.Representation = UsualGroupRepresentation.None;
			SegmentsGroup.VerticalStretch = False;
			SegmentsGroup.Height = 1;
			
		EndIf;
		
		ItemSegment = Items.Add("Segment_" + SegmentsFilterString.GetID(), Type("FormField"), SegmentsGroup);
		ItemSegment.Type = FormFieldType.LabelField;
		ItemSegment.DataPath = "FilterSegments[" + ItemNumber + "].Presentation";
		ItemSegment.Hyperlink = True;
		ItemSegment.TitleLocation = FormItemTitleLocation.None;
		ItemSegment.ToolTip = Selection.Presentation;
		ItemSegment.TextColor = StyleColors.FieldTextColor;
		ItemSegment.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemSegment.Width = StrLen(SegmentPresentation);
		ItemSegment.HorizontalStretch = False;
		ItemSegment.SetAction("Click", "Attachable_SegmentFilterClick");
		
		ItemNumber = ItemNumber + 1;
		
	EndDo;
	
	If Selection.Count() = 0 Then
		
		ItemExplanation = Items.Add("Segment_Explanation", Type("FormDecoration"), Items.FilterValuesSegments);
		ItemExplanation.Type = FormDecorationType.Label;
		ItemExplanation.Hyperlink = True;
		ItemExplanation.Title = NStr("en = 'How to work with counterparty segments?'; ru = 'Работа с сегментами контрагентов';pl = 'Jak pracować z segmentami kontrahenta?';es_ES = '¿Cómo trabajar con los segmentos de contrapartida?';es_CO = '¿Cómo trabajar con los segmentos de contrapartida?';tr = 'Cari hesap segmentleriyle nasıl çalışılır?';it = 'Come lavorare con segmenti controparte?';de = 'Wie arbeitet man mit den Segmenten des Geschäftspartners?'");
		ItemExplanation.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemExplanation.SetAction("Click", "Attachable_SegmentFilterClick");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HelperProceduresAndFunctions

// Tag creation function
//
// Parameters:
//  TagName - String - tag
// name Return value:
//  CatalogRef.Tags - reference to created item
Function CreateTag(TagName) Export
	
	NewTag = Catalogs.Tags.CreateItem();
	NewTag.Description = TagName;
	NewTag.Write();
	
	Return NewTag.Ref;
	
EndFunction

// Procedure changes color of the filter item depending
// on the sign of use It is required to call from the server for connected procedures, otherwise, the color is not rendered
//
// Parameters:
//  Form		 - list
//  form Mark		 - Boolean - Shows that filter by this
//  item ItemName is used	 - String - form item name
Procedure ChangeSelectionItemColor(Form, Mark, ItemName) Export
	
	FilterItem = Form.Items.Find(ItemName);
	If FilterItem = Undefined Then
		Return;
	EndIf;
	
	If Mark Then
		FilterItem.BackColor = StyleColors.FilterActiveValueBackground;
	Else
		FilterItem.BackColor = New Color;
	EndIf;
	
EndProcedure

#EndRegion

#Region Counterparties

Function CounterpartyRelationshipTypeByOperationKind(OperationKind) Export
	
	Result = New Structure("Customer, Supplier, OtherRelationship", False, False, False);
	
	If TypeOf(OperationKind) = Type("EnumRef.OperationTypesGoodsReceipt") Then
		
		If OperationKind = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
			Or OperationKind = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
			Result.Customer = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesGoodsIssue") Then
		
		If OperationKind = Enums.OperationTypesGoodsIssue.SaleToCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
			Result.Customer = True;
			Result.Supplier = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesCashReceipt") Then
		
		If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesCashReceipt.Other Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesCashVoucher") Then
		
		If OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesPaymentReceipt") Then
		
		If OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesPaymentExpense") Then
		
		If OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesArApAdjustments") Then
		
		If OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.DebtAssignmentToVendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment Then
			Result.Supplier = True;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure ExecuteCounterpartySegmentsGeneration(Parameters = Undefined, ResultAddress = Undefined) Export

	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.CounterpartySegmentGeneration);
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	EventName = NStr("en = 'Counterparty segment generation. Scheduled launch'; ru = 'Создание сегмента контрагента. Запуск по расписанию';pl = 'Generacja segmentu kontrahenta. Zaplanowane uruchomienie';es_ES = 'Generación de segmentos de contrapartida. Lanzamiento programado';es_CO = 'Generación de segmentos de contrapartida. Lanzamiento programado';tr = 'Cari hesap segmenti oluşturma. Planlanmış başlatma';it = 'Segmento controparte';de = 'Generierung von Geschäftspartnersegment. Geplanter Start'", CommonClientServer.DefaultLanguageCode());
	WriteLogEvent(EventName,
				 EventLogLevel.Note,
				 ,
				 ,
				 NStr("en = 'Start'; ru = 'Начало';pl = 'Rozpocznij';es_ES = 'Iniciar';es_CO = 'Iniciar';tr = 'Başlangıç';it = 'Inizio';de = 'Starten'",
				 CommonClientServer.DefaultLanguageCode()));
	Try
		If TypeOf(Parameters) = Type("Structure")
			And Parameters.Property("Segment") Then
			GenerateCounterpartySegments(Parameters.Segment);
		Else
			GenerateCounterpartySegments();
		EndIf;
	Except
		WriteLogEvent(EventName, 
		              EventLogLevel.Error,
		              "",
		              NStr("en = 'Counterparty segment generation error'; ru = 'Ошибка создания сегмента контрагента';pl = 'Błąd generacji segmentu kontrahenta';es_ES = 'Error de generación de segmento de contrapartida';es_CO = 'Error de generación de segmento de contrapartida';tr = 'Cari hesap segmenti oluşturma hatası';it = 'Errore nella generazione del segmento controparte';de = 'Fehler beim Generierung von Geschäftspartnersegmenten'", CommonClientServer.DefaultLanguageCode()),
		              ErrorInfo());
	EndTry;
	
	WriteLogEvent(EventName, EventLogLevel.Note, "", NStr("en = 'Finish'; ru = 'Готово';pl = 'Koniec';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Termina';de = 'Beenden'", CommonClientServer.DefaultLanguageCode()));
	
EndProcedure

Procedure GenerateCounterpartySegments(SegmentRef = Undefined) Export

	PM = PrivilegedMode();
	If Not PM Then
		SetPrivilegedMode(True);
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CounterpartySegments.Ref AS Segment
	|FROM
	|	Catalog.CounterpartySegments AS CounterpartySegments
	|WHERE
	|	&SegmentCondition
	|	AND NOT CounterpartySegments.DeletionMark";
	
	If ValueIsFilled(SegmentRef) Then
		Query.Text = StrReplace(Query.Text, "&SegmentCondition", "CounterpartySegments.Ref = &Segment");
		Query.SetParameter("Segment", SegmentRef);
	Else
		Query.Text = StrReplace(Query.Text, "&SegmentCondition", "TRUE");	
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		CounterpartiesArray = Catalogs.CounterpartySegments.GetSegmentContent(Selection.Segment);
		
		RecordSet = InformationRegisters.CounterpartySegments.CreateRecordSet();
		RecordSet.Filter.Segment.Set(Selection.Segment);
		
		For Each Counterparty In CounterpartiesArray Do
			Record = RecordSet.Add();
			Record.Segment = Selection.Segment;
			Record.Counterparty = Counterparty;
		EndDo;
		
		RecordSet.Write();
		
	EndDo;
	
	If Not PM Then
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

// Generates documents in according with the settings of SubscriptionPlan.
// For sales and tax invoices generates print forms for periodical sending to the customers.
//
Procedure CreateDocumentsOnSubscription(SubscriptionPlan) Export
	
	SubscriptionAttributes = Common.ObjectAttributesValues(SubscriptionPlan, "TypeOfDocument, Company, ScheduledJobUUID");
	
	StructureData = New Structure;
	StructureData.Insert("SubscriptionPlan", SubscriptionPlan);
	StructureData.Insert("DocumentDate", CurrentSessionDate());
	StructureData.Insert("Company", SubscriptionAttributes.Company);
	StructureData.Insert("ScheduledJobUUID", SubscriptionAttributes.ScheduledJobUUID);
	StructureData.Insert("SendingDocuments");
	
	StructureData.Insert("PurchaseOrderSchedule", 
		SubscriptionAttributes.TypeOfDocument = "PurchaseOrder"
		Or SubscriptionAttributes.TypeOfDocument = "SupplierInvoice");
		
	StructureData.Insert("TypeOfDocument", SubscriptionAttributes.TypeOfDocument);
	
	CreateTaxInvoices =
		SubscriptionAttributes.TypeOfDocument = "SalesInvoice" And
		WorkWithVAT.GetUseTaxInvoiceForPostingVAT(StructureData.DocumentDate, StructureData.Company);
		
	StructureData.Insert("CreateTaxInvoices", CreateTaxInvoices);
	
	If SubscriptionPlan.TypeOfDocument = "SupplierInvoice"
		And ValueIsFilled(SubscriptionPlan.Template) Then
		
		StructureData.Insert("Template", Common.ObjectAttributeValue(SubscriptionPlan, "Template"));
		
		GenerateDocumentsBySubscriptionPlanFromTemplate(StructureData);
		
	Else 
		
		SendingDocuments = GenerateDocumentsBySubscriptionPlan(StructureData);
		
		StructureData.Insert("SendingDocuments", SendingDocuments);
		DriveServer.SendEmailsBySubscription(StructureData);
		
	EndIf;
	
EndProcedure

Function GenerateDocumentsBySubscriptionPlanFromTemplate(StructureData)
	
	ReceiptDate			= CurrentSessionDate();
	DocumentCurrency	= Common.ObjectAttributeValue(StructureData.Template, "DocumentCurrency");
	
	StructureQueryData = GetStructureQueryDataForTemplate(StructureData);
	
	If StructureQueryData.IsUserDefined Then
		
		ValueListDatesToDelete = New ValueList;
		
	EndIf;
	
	Query = New Query;
	Query.Text = StructureQueryData.QueryText;
		
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("DocumentDate", StructureData.DocumentDate);
	Query.SetParameter("IsSupplierInvoice", True);
	Query.SetParameter("ReceiptDate", ReceiptDate);
	Query.SetParameter("SubscriptionPlan", StructureData.SubscriptionPlan);
	
	QueryResult = Query.Execute();
	
	SelectionSubscription = QueryResult.Select();
	
	While SelectionSubscription.Next() Do
		
		DocumentObject = Documents[StructureData.TypeOfDocument].CreateDocument();
		
		FillPropertyValues(DocumentObject, StructureData.Template, , "Number, Date");
		
		DocumentObject.Date = StructureData.DocumentDate;
		DocumentObject.SetNewNumber();
		
		DocumentObject.Comment = GenerateCommentBySubscriptionPlan(StructureData.SubscriptionPlan, StructureData.TypeOfDocument);
		DocumentObject.ContractCurrencyExchangeRate = SelectionSubscription.ExchangeRate;
		DocumentObject.ContractCurrencyMultiplicity = SelectionSubscription.Multiplicity;
		
		If StructureData.TypeOfDocument = "SupplierInvoice" Then
			DocumentObject.Schedule = StructureData.SubscriptionPlan;
		EndIf;
		
		DocumentObject.Inventory.Load(Common.ObjectAttributeValue(StructureData.Template, "Inventory").Unload());
		DocumentObject.Expenses.Load(Common.ObjectAttributeValue(StructureData.Template, "Expenses").Unload());
		DocumentObject.Materials.Load(Common.ObjectAttributeValue(StructureData.Template, "Materials").Unload());
		
		For Each LineDocument In DocumentObject.Inventory Do
		
			Catalogs.SubscriptionPlans.ReplaceParameterInContent(
				LineDocument.Content, 
				SelectionSubscription.ChargeFrequency,
				SelectionSubscription.Date);
		
		EndDo;
			
		For Each LineDocument In DocumentObject.Expenses Do
		
			Catalogs.SubscriptionPlans.ReplaceParameterInContent(
				LineDocument.Content, 
				SelectionSubscription.ChargeFrequency,
				SelectionSubscription.Date);
		
		EndDo;
			
		For Each LineDocument In DocumentObject.Materials Do
		
			Catalogs.SubscriptionPlans.ReplaceParameterInContent(
				LineDocument.Content, 
				SelectionSubscription.ChargeFrequency,
				SelectionSubscription.Date);
		
		EndDo;
			
		WriteMode = DocumentWriteMode.Write;
		
		If DocumentObject.CheckFilling() Then
			WriteMode = DocumentWriteMode.Posting;
		Else
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error found in %1. Subscription plan: %2.'; ru = 'Обнаружена ошибка в %1. План подписки: %2.';pl = 'Wykryto błąd w %1. Plan subskrypcji: %2.';es_ES = 'Se ha encontrado un error en %1. Plan de suscripción: %2.';es_CO = 'Se ha encontrado un error en %1. Plan de suscripción: %2.';tr = 'Şurada hata bulundu: %1. Abonelik planı: %2.';it = 'Rilevato errore in %1. Piano di abbonamento: %2.';de = 'Fehler gefunden in %1. Abonnement-Plan: %2.'",
					CommonClientServer.DefaultLanguageCode()),
				DocumentObject,
				StructureData.SubscriptionPlan);
			
			WriteLogEvent(
				NStr("en = 'Recurring invoicing'; ru = 'Регулярное выставление счетов';pl = 'Faktury cykliczne';es_ES = 'Facturación recurrente';es_CO = 'Facturación recurrente';tr = 'Yinelenen faturalandırma';it = 'Fatturazione ricorrente';de = 'Wiederkehrende Rechnungsstellung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.ScheduledJobs.CreateDocumentsOnSubscription,
				,
				ErrorDescription);
			
		EndIf;
			
		BeginTransaction();
		
		Try
			
			DocumentObject.Write(WriteMode);
			
			If StructureQueryData.IsUserDefined Then
				
				WriteGeneratedDocumentsData(SelectionSubscription, StructureData, ValueListDatesToDelete);
				
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			CommonClientServer.MessageToUser(ErrorInfo());
			
			If WriteMode = DocumentWriteMode.Posting Then
				TextMessage = NStr(
					"en = 'Couldn''t post %1. Subscription plan: %2.
					|Details: %3'; 
					|ru = 'Не удалось провести %1. План подписки: %2.
					|Подробнее: %3';
					|pl = 'Nie udało się zatwierdzić %1. Plan subskrypcji: %2.
					|Szczegóły: %3';
					|es_ES = 'No se pudo publicar %1. Plan de suscripción: %2
					|Detalles: %3';
					|es_CO = 'No se pudo publicar %1. Plan de suscripción: %2
					|Detalles: %3';
					|tr = '%1 kaydedilemedi. Abonelik planı: %2.
					|Ayrıntılar: %3';
					|it = 'Impossibile pubblicare %1. Piano di abbonamento: %2.
					|Dettagli: %3';
					|de = 'Fehler beim Buchen von %1. Abonnement-Plan: %2.
					|Details: %3'", 
					CommonClientServer.DefaultLanguageCode());
			Else 
				TextMessage = NStr(
					"en = 'Couldn''t save %1. Subscription plan: %2.
					|Details: %3'; 
					|ru = 'Не удалось записать %1. План подписки: %2.
					|Подробнее: %3';
					|pl = 'Nie udało się zapisać %1. Plan subskrypcji: %2.
					|Szczegóły: %3';
					|es_ES = 'No se pudo guardar %1. Plan de suscripción: %2
					|Detalles: %3';
					|es_CO = 'No se pudo guardar %1. Plan de suscripción: %2
					|Detalles: %3';
					|tr = '%1 saklanamadı. Abonelik planı: %2.
					|Ayrıntılar: %3';
					|it = 'Impossibile salvare %1. Piano di abbonamento: %2.
					|Dettagli: %3';
					|de = 'Fehler beim Speichern %1. Abonnement-Plan: %2.
					|Details: %3'", 
					CommonClientServer.DefaultLanguageCode());
			EndIf;
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				TextMessage,
				DocumentObject.Ref,
				StructureData.SubscriptionPlan,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				NStr("en = 'Recurring invoicing'; ru = 'Регулярное выставление счетов';pl = 'Faktury cykliczne';es_ES = 'Facturación recurrente';es_CO = 'Facturación recurrente';tr = 'Yinelenen faturalandırma';it = 'Fatturazione ricorrente';de = 'Wiederkehrende Rechnungsstellung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.ScheduledJobs.CreateDocumentsOnSubscription,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
	If StructureQueryData.IsUserDefined Then
		DeleteRecordsGeneratedDocumentsData(ValueListDatesToDelete, StructureData);
	EndIf;
	
EndFunction

Function GenerateDocumentsBySubscriptionPlan(StructureData) Export
	
	SendingDocuments		= New Array;
	PurchaseOrderSchedule	= StructureData.PurchaseOrderSchedule;
	TypeOfDocument			= StructureData.TypeOfDocument;
	ReceiptDate				= CurrentSessionDate();
	
	StructureQueryData = GetStructureQueryData(StructureData);
	
	If StructureQueryData.IsUserDefined Then
		
		ValueListDatesToDelete = New ValueList;
		
	EndIf;
	
	Query = New Query;
	
	Query.Text = StructureQueryData.QueryText;
	
	Query.SetParameter("SubscriptionPlan", StructureData.SubscriptionPlan);
	Query.SetParameter("DocumentDate", StructureData.DocumentDate);
	Query.SetParameter("PurchaseOrderSchedule", PurchaseOrderSchedule);
	Query.SetParameter("ReceiptDate", ReceiptDate);
	
	Query.SetParameter("IsSalesInvoice", TypeOfDocument = "SalesInvoice");
	Query.SetParameter("IsPurchaseOrder", TypeOfDocument = "PurchaseOrder");
	Query.SetParameter("IsSupplierInvoice", TypeOfDocument = "SupplierInvoice");
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[StructureQueryData.NumberHeader].Select();
	
	While Selection.Next() Do
		
		If TypeOfDocument = "SupplierInvoice" Then
			
			Document = Documents.SupplierInvoice.CreateDocument();
			
		ElsIf PurchaseOrderSchedule Then
			
			Document = Documents.PurchaseOrder.CreateDocument();
			
		Else
			
			Document = Documents.SalesInvoice.CreateDocument();
			
		EndIf;
		
		FillPropertyValues(Document, Selection);
		
		Document.Comment = GenerateCommentBySubscriptionPlan(StructureData.SubscriptionPlan, TypeOfDocument);
		Document.ContractCurrencyExchangeRate = Document.ExchangeRate;
		Document.ContractCurrencyMultiplicity = Document.Multiplicity;

		InventorySelection = QueryResults[StructureQueryData.NumberInventory].Select();
		
		While InventorySelection.Next() Do
			
			If TypeOfDocument = "SupplierInvoice" 
				And InventorySelection.ProductsType = Enums.ProductsTypes.Service Then
				
				NewRow = Document.Expenses.Add();
				
			ElsIf (TypeOfDocument = "SupplierInvoice" Or TypeOfDocument = "PurchaseOrder")
				And InventorySelection.ProductsType = Enums.ProductsTypes.Work Then
				
				Continue;
				
			Else
				
				NewRow = Document.Inventory.Add();
				
			EndIf;
			
			FillPropertyValues(NewRow, InventorySelection);
			Catalogs.SubscriptionPlans.ReplaceParameterInContent(NewRow.Content, Selection.ChargeFrequency, Selection.Date);
			
		EndDo;
		
		For Each TabularSectionRow In Document.Inventory Do
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			TabularSectionRow.VATAmount = ?(
				Document.AmountIncludesVAT, 
				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
				TabularSectionRow.Amount * VATRate / 100);
				
			TabularSectionRow.Total = TabularSectionRow.Amount + 
				?(Document.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(Document);
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			GLAccountsInDocuments.FillGLAccountsInDocument(Document);
		EndIf;
		
		PaymentTermsServer.FillPaymentCalendarFromContract(Document);
		Document.SetPaymentTerms = Document.PaymentCalendar.Count() > 0;
		
		WriteMode = DocumentWriteMode.Write;
		
		If TypeOfDocument = "PurchaseOrder" Then
			
			Document.OrderState = GetPurchaseOrderstate(Document.OrderState);
			Document.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForPurchase;
			
		ElsIf TypeOfDocument = "SupplierInvoice" Then
			
			Document.OperationKind		= Enums.OperationTypesSupplierInvoice.Invoice;
			
			WriteMode = DocumentWriteMode.Posting;
			
			If Document.CheckFilling() Then
				WriteMode = DocumentWriteMode.Posting;
			Else
				
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Error found in %1. Subscription plan: %2.'; ru = 'Обнаружена ошибка в %1. План подписки: %2.';pl = 'Wykryto błąd w %1. Plan subskrypcji: %2.';es_ES = 'Se ha encontrado un error en %1. Plan de suscripción: %2.';es_CO = 'Se ha encontrado un error en %1. Plan de suscripción: %2.';tr = 'Şurada hata bulundu: %1. Abonelik planı: %2.';it = 'Rilevato errore in %1. Piano di abbonamento: %2.';de = 'Fehler gefunden in %1. Abonnement-Plan: %2.'",
						CommonClientServer.DefaultLanguageCode()),
					Document,
					Selection.Subscription);
				
				WriteLogEvent(
					NStr("en = 'Recurring invoicing'; ru = 'Регулярное выставление счетов';pl = 'Faktury cykliczne';es_ES = 'Facturación recurrente';es_CO = 'Facturación recurrente';tr = 'Yinelenen faturalandırma';it = 'Fatturazione ricorrente';de = 'Wiederkehrende Rechnungsstellung'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.ScheduledJobs.CreateDocumentsOnSubscription,
					,
					ErrorDescription);
				
			EndIf;
			
		Else
			
			Document.OperationKind = Enums.OperationTypesSalesInvoice.Invoice;
			
			If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes Then
				Document.FillPrepayment();
			EndIf;
			
			If Selection.ActionOnCreating = Enums.ActionsOnInvoiceCreating.Send Then
				
				If Document.CheckFilling() Then
					WriteMode = DocumentWriteMode.Posting;
				Else
					
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Error found in %1. Subscription plan: %2.'; ru = 'Обнаружена ошибка в %1. План подписки: %2.';pl = 'Wykryto błąd w %1. Plan subskrypcji: %2.';es_ES = 'Se ha encontrado un error en %1. Plan de suscripción: %2.';es_CO = 'Se ha encontrado un error en %1. Plan de suscripción: %2.';tr = 'Şurada hata bulundu: %1. Abonelik planı: %2.';it = 'Rilevato errore in %1. Piano di abbonamento: %2.';de = 'Fehler gefunden in %1. Abonnement-Plan: %2.'",
							CommonClientServer.DefaultLanguageCode()),
						Document,
						Selection.Subscription);
					
					WriteLogEvent(
						NStr("en = 'Recurring invoicing'; ru = 'Регулярное выставление счетов';pl = 'Faktury cykliczne';es_ES = 'Facturación recurrente';es_CO = 'Facturación recurrente';tr = 'Yinelenen faturalandırma';it = 'Fatturazione ricorrente';de = 'Wiederkehrende Rechnungsstellung'", CommonClientServer.DefaultLanguageCode()),
						EventLogLevel.Error,
						Metadata.ScheduledJobs.CreateDocumentsOnSubscription,
						,
						ErrorDescription);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
			
		BeginTransaction();
		
		Try
			
			Document.Write(WriteMode);
			
			If StructureQueryData.IsUserDefined Then
				
				WriteGeneratedDocumentsData(Selection, StructureData, ValueListDatesToDelete);
				
			Else 
				
				PlannedDate = GetPlannedDate(Selection);
				WriteGeneratedDocumentsData(Selection, StructureData, , PlannedDate);
				
			EndIf;
			
			CommitTransaction();
			
			If Not PurchaseOrderSchedule And 
				Selection.ActionOnCreating = Enums.ActionsOnInvoiceCreating.Send Then
				
				SendingDocuments.Add(Document.Ref);
			EndIf;
			
		Except
			
			RollbackTransaction();
			
			If WriteMode = DocumentWriteMode.Posting Then
				TextMessage = NStr(
					"en = 'Couldn''t post %1. Subscription plan: %2.
					|Details: %3'; 
					|ru = 'Не удалось провести %1. План подписки: %2.
					|Подробнее: %3';
					|pl = 'Nie udało się zatwierdzić %1. Plan subskrypcji: %2.
					|Szczegóły: %3';
					|es_ES = 'No se pudo publicar %1. Plan de suscripción: %2
					|Detalles: %3';
					|es_CO = 'No se pudo publicar %1. Plan de suscripción: %2
					|Detalles: %3';
					|tr = '%1 kaydedilemedi. Abonelik planı: %2.
					|Ayrıntılar: %3';
					|it = 'Impossibile pubblicare %1. Piano di abbonamento: %2.
					|Dettagli: %3';
					|de = 'Fehler beim Buchen von %1. Abonnement-Plan: %2.
					|Details: %3'", 
					CommonClientServer.DefaultLanguageCode());
			Else 
				TextMessage = NStr(
					"en = 'Couldn''t save %1. Subscription plan: %2.
					|Details: %3'; 
					|ru = 'Не удалось записать %1. План подписки: %2.
					|Подробнее: %3';
					|pl = 'Nie udało się zapisać %1. Plan subskrypcji: %2.
					|Szczegóły: %3';
					|es_ES = 'No se pudo guardar %1. Plan de suscripción: %2
					|Detalles: %3';
					|es_CO = 'No se pudo guardar %1. Plan de suscripción: %2
					|Detalles: %3';
					|tr = '%1 saklanamadı. Abonelik planı: %2.
					|Ayrıntılar: %3';
					|it = 'Impossibile salvare %1. Piano di abbonamento: %2.
					|Dettagli: %3';
					|de = 'Fehler beim Speichern %1. Abonnement-Plan: %2.
					|Details: %3'", 
					CommonClientServer.DefaultLanguageCode());
			EndIf;
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				TextMessage,
				Document.Ref,
				Selection.Subscription,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'Recurring invoicing'; ru = 'Регулярное выставление счетов';pl = 'Faktury cykliczne';es_ES = 'Facturación recurrente';es_CO = 'Facturación recurrente';tr = 'Yinelenen faturalandırma';it = 'Fatturazione ricorrente';de = 'Wiederkehrende Rechnungsstellung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.ScheduledJobs.CreateDocumentsOnSubscription,
				,
				ErrorDescription);
				
			Continue;
			
		EndTry;
		
		If StructureData.CreateTaxInvoices Then
			WorkWithVAT.CreateTaxInvoice(WriteMode, Document.Ref);
		EndIf;
	
	EndDo;
	
	If StructureQueryData.IsUserDefined Then
		
		DeleteRecordsGeneratedDocumentsData(ValueListDatesToDelete, StructureData);
		
	EndIf;
	
	Return SendingDocuments;
		
EndFunction

Function GetStructureQueryDataForTemplate(StructureData)
	
	StructureQueryData = New Structure;
	
	StructureQueryData.Insert("QueryText");
	StructureQueryData.Insert("IsUserDefined");
	
	StructureQueryData.IsUserDefined = 
		(Common.ObjectAttributeValue(StructureData.SubscriptionPlan, "UseCustomSchedule"));

	If StructureQueryData.IsUserDefined Then
		
		StructureQueryData.QueryText = 
		"SELECT ALLOWED
		|	SubscriptionPlans.Ref AS Subscription,
		|	SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	&DocumentDate AS Date,
		|	SubscriptionPlans.Company AS Company,
		|	Subscriptions.Counterparty AS Counterparty,
		|	Subscriptions.Contract AS Contract,
		|	SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.DefaultVATRate, VALUE(Catalog.VATRates.EmptyRef)) = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN VALUE(Catalog.VATRates.Exempt)
		|		ELSE AccountingPolicySliceLast.DefaultVATRate
		|	END AS VATRate,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.RegisteredForVAT, FALSE)
		|			THEN VALUE(Enum.VATTaxationTypes.SubjectToVAT)
		|		ELSE VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|	END AS CompanyVATTaxation,
		|	Subscriptions.Counterparty.VATTaxation AS CounterpartyVATTaxation,
		|	&DocumentCurrency AS DocumentCurrency,
		|	Companies.VATNumber AS CompanyVATNumber
		|INTO TT_SubscriptionPlans
		|FROM
		|	Catalog.SubscriptionPlans AS SubscriptionPlans
		|		INNER JOIN InformationRegister.Subscriptions AS Subscriptions
		|		ON SubscriptionPlans.Ref = Subscriptions.SubscriptionPlan
		|			AND (&DocumentDate >= Subscriptions.StartDate)
		|			AND (SubscriptionPlans.Enabled)
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&DocumentDate, ) AS AccountingPolicySliceLast
		|		ON SubscriptionPlans.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON SubscriptionPlans.Company = Companies.Ref
		|WHERE
		|	SubscriptionPlans.Ref = &SubscriptionPlan
		|
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_SubscriptionPlans.Subscription AS Subscription,
		|	TT_SubscriptionPlans.Subscription AS Schedule,
		|	TT_SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	TT_SubscriptionPlans.Date AS Date,
		|	TT_SubscriptionPlans.Company AS Company,
		|	TT_SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	TT_SubscriptionPlans.VATRate AS VATRate,
		|	TT_SubscriptionPlans.Counterparty AS Counterparty,
		|	TT_SubscriptionPlans.Contract AS Contract,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Rate, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Rate, 1)
		|	END AS ExchangeRate,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Repetition, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Repetition, 1)
		|	END AS Multiplicity,
		|	CASE
		|		WHEN TT_SubscriptionPlans.CounterpartyVATTaxation <> VALUE(Enum.VATTaxationTypes.EmptyRef)
		|				AND (NOT TT_SubscriptionPlans.CompanyVATTaxation = VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ForExport))
		|			THEN TT_SubscriptionPlans.CounterpartyVATTaxation
		|		ELSE TT_SubscriptionPlans.CompanyVATTaxation
		|	END AS VATTaxation,
		|	&ReceiptDate AS ReceiptDate,
		|	GeneratedDocumentsData.PlannedDate AS PlannedDate
		|FROM
		|	TT_SubscriptionPlans AS TT_SubscriptionPlans
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
		|		ON TT_SubscriptionPlans.Company = ExchangeRateSliceLast.Company
		|			AND TT_SubscriptionPlans.DocumentCurrency = ExchangeRateSliceLast.Currency
		|		INNER JOIN InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
		|		ON TT_SubscriptionPlans.Subscription = GeneratedDocumentsData.SubscriptionPlan
		|			AND TT_SubscriptionPlans.Counterparty <> GeneratedDocumentsData.Counterparty
		|			AND TT_SubscriptionPlans.Contract <> GeneratedDocumentsData.Contract
		|			AND (GeneratedDocumentsData.ActualDate = DATETIME(1, 1, 1))
		|WHERE
		|	GeneratedDocumentsData.PlannedDate <= &DocumentDate";
		
	Else 
		
		StructureQueryData.QueryText = 
		"SELECT ALLOWED
		|	SubscriptionPlans.Ref AS Subscription,
		|	SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	&DocumentDate AS Date,
		|	SubscriptionPlans.Company AS Company,
		|	Subscriptions.Counterparty AS Counterparty,
		|	Subscriptions.Contract AS Contract,
		|	SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	CASE
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Day)
		|			THEN BEGINOFPERIOD(&DocumentDate, DAY)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Month)
		|			THEN BEGINOFPERIOD(&DocumentDate, MONTH)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Year)
		|			THEN BEGINOFPERIOD(&DocumentDate, YEAR)
		|	END AS BeginOfChargePeriod,
		|	CASE
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Day)
		|			THEN ENDOFPERIOD(&DocumentDate, DAY)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Month)
		|			THEN ENDOFPERIOD(&DocumentDate, MONTH)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Year)
		|			THEN ENDOFPERIOD(&DocumentDate, YEAR)
		|	END AS EndOfChargePeriod,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.DefaultVATRate, VALUE(Catalog.VATRates.EmptyRef)) = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN VALUE(Catalog.VATRates.Exempt)
		|		ELSE AccountingPolicySliceLast.DefaultVATRate
		|	END AS VATRate,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.RegisteredForVAT, FALSE)
		|			THEN VALUE(Enum.VATTaxationTypes.SubjectToVAT)
		|		ELSE VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|	END AS CompanyVATTaxation,
		|	Subscriptions.Counterparty.VATTaxation AS CounterpartyVATTaxation,
		|	&DocumentCurrency AS DocumentCurrency,
		|	Companies.VATNumber AS CompanyVATNumber
		|INTO TT_SubscriptionPlans
		|FROM
		|	Catalog.SubscriptionPlans AS SubscriptionPlans
		|		INNER JOIN InformationRegister.Subscriptions AS Subscriptions
		|		ON SubscriptionPlans.Ref = Subscriptions.SubscriptionPlan
		|			AND (&DocumentDate >= Subscriptions.StartDate)
		|			AND (SubscriptionPlans.Enabled)
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&DocumentDate, ) AS AccountingPolicySliceLast
		|		ON SubscriptionPlans.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON SubscriptionPlans.Company = Companies.Ref
		|WHERE
		|	SubscriptionPlans.Ref = &SubscriptionPlan
		|	AND CASE
		|			WHEN Subscriptions.EndDate = DATETIME(1, 1, 1)
		|				THEN TRUE
		|			ELSE BEGINOFPERIOD(&DocumentDate, DAY) <= Subscriptions.EndDate
		|		END
		|
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_SubscriptionPlans.Subscription AS Subscription,
		|	TT_SubscriptionPlans.Subscription AS Schedule,
		|	TT_SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	TT_SubscriptionPlans.Date AS Date,
		|	TT_SubscriptionPlans.Company AS Company,
		|	TT_SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	TT_SubscriptionPlans.VATRate AS VATRate,
		|	TT_SubscriptionPlans.Counterparty AS Counterparty,
		|	TT_SubscriptionPlans.Contract AS Contract,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Rate, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Rate, 1)
		|	END AS ExchangeRate,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Repetition, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Repetition, 1)
		|	END AS Multiplicity,
		|	CASE
		|		WHEN TT_SubscriptionPlans.CounterpartyVATTaxation <> VALUE(Enum.VATTaxationTypes.EmptyRef)
		|				AND (NOT TT_SubscriptionPlans.CompanyVATTaxation = VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ForExport))
		|			THEN TT_SubscriptionPlans.CounterpartyVATTaxation
		|		ELSE TT_SubscriptionPlans.CompanyVATTaxation
		|	END AS VATTaxation,
		|	&ReceiptDate AS ReceiptDate,
		|	TT_SubscriptionPlans.CompanyVATNumber AS CompanyVATNumber
		|FROM
		|	TT_SubscriptionPlans AS TT_SubscriptionPlans
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
		|		ON TT_SubscriptionPlans.Company = ExchangeRateSliceLast.Company
		|			AND TT_SubscriptionPlans.DocumentCurrency = ExchangeRateSliceLast.Currency
		|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoice
		|		ON (&IsSupplierInvoice)
		|			AND (NOT SupplierInvoice.DeletionMark)
		|			AND TT_SubscriptionPlans.BeginOfChargePeriod <= SupplierInvoice.Date
		|			AND TT_SubscriptionPlans.EndOfChargePeriod >= SupplierInvoice.Date
		|			AND TT_SubscriptionPlans.Subscription = SupplierInvoice.Schedule
		|			AND TT_SubscriptionPlans.Counterparty = SupplierInvoice.Counterparty
		|			AND TT_SubscriptionPlans.Contract = SupplierInvoice.Contract
		|WHERE
		|	SupplierInvoice.Ref IS NULL";
		
	EndIf;
	
	Return StructureQueryData;
	
EndFunction

Function GetStructureQueryData(StructureData)
	
	StructureQueryData = New Structure;
	
	StructureQueryData.Insert("QueryText");
	StructureQueryData.Insert("NumberHeader");
	StructureQueryData.Insert("NumberInventory");
	StructureQueryData.Insert("IsUserDefined");
	
	StructureQueryData.IsUserDefined = 
		(Common.ObjectAttributeValue(StructureData.SubscriptionPlan, "UseCustomSchedule"));
	
	If StructureQueryData.IsUserDefined Then
		
		StructureQueryData.QueryText = 
		"SELECT ALLOWED
		|	Subscriptions.SubscriptionPlan AS SubscriptionPlan,
		|	Subscriptions.Counterparty AS Counterparty,
		|	Subscriptions.Contract AS Contract,
		|	Subscriptions.EmailTo AS EmailTo,
		|	Subscriptions.StartDate AS StartDate,
		|	Subscriptions.EndDate AS EndDate
		|INTO TT_Subscriptions
		|FROM
		|	InformationRegister.Subscriptions AS Subscriptions
		|WHERE
		|	Subscriptions.SubscriptionPlan = &SubscriptionPlan
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubscriptionPlans.Ref AS Subscription,
		|	SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	&DocumentDate AS Date,
		|	SubscriptionPlans.Company AS Company,
		|	SubscriptionPlans.ActionOnCreating AS ActionOnCreating,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.DefaultVATRate, VALUE(Catalog.VATRates.EmptyRef)) = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN VALUE(Catalog.VATRates.Exempt)
		|		ELSE AccountingPolicySliceLast.DefaultVATRate
		|	END AS VATRate,
		|	Subscriptions.Counterparty AS Counterparty,
		|	Subscriptions.Contract AS Contract,
		|	Subscriptions.EmailTo AS EmailTo,
		|	CASE
		|		WHEN Subscriptions.Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|				OR Subscriptions.Contract.SettlementsCurrency = VALUE(Catalog.Currencies.EmptyRef)
		|			THEN FunctionalCurrency.Value
		|		ELSE Subscriptions.Contract.SettlementsCurrency
		|	END AS DocumentCurrency,
		|	CASE
		|		WHEN Subscriptions.Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|				OR Subscriptions.Contract.PriceKind = VALUE(Catalog.PriceTypes.EmptyRef)
		|			THEN CASE
		|					WHEN Subscriptions.Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
		|							OR Subscriptions.Counterparty.PriceKind = VALUE(Catalog.PriceTypes.EmptyRef)
		|						THEN VALUE(Catalog.PriceTypes.Wholesale)
		|					ELSE Subscriptions.Counterparty.PriceKind
		|				END
		|		ELSE Subscriptions.Contract.PriceKind
		|	END AS PriceKind,
		|	CASE
		|		WHEN Subscriptions.Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|				OR Subscriptions.Contract.Department = VALUE(Catalog.BusinessUnits.EmptyRef)
		|			THEN VALUE(Catalog.BusinessUnits.MainDepartment)
		|		ELSE Subscriptions.Contract.Department
		|	END AS Department,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.RegisteredForVAT, FALSE)
		|			THEN VALUE(Enum.VATTaxationTypes.SubjectToVAT)
		|		ELSE VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|	END AS CompanyVATTaxation,
		|	Subscriptions.Counterparty.VATTaxation AS CounterpartyVATTaxation,
		|	SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	Companies.VATNumber AS CompanyVATNumber,
		|	SubscriptionPlans.ScheduledJobUUID AS ScheduledJobUUID
		|INTO TT_SubscriptionPlans
		|FROM
		|	Catalog.SubscriptionPlans AS SubscriptionPlans
		|		INNER JOIN TT_Subscriptions AS Subscriptions
		|		ON SubscriptionPlans.Ref = Subscriptions.SubscriptionPlan
		|			AND (&DocumentDate >= Subscriptions.StartDate)
		|			AND (SubscriptionPlans.Enabled)
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&DocumentDate, ) AS AccountingPolicySliceLast
		|		ON SubscriptionPlans.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON SubscriptionPlans.Company = Companies.Ref,
		|	Constant.FunctionalCurrency AS FunctionalCurrency
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_SubscriptionPlans.Subscription AS Subscription,
		|	TT_SubscriptionPlans.VATRate AS VATRate
		|INTO TT_VAT
		|FROM
		|	TT_SubscriptionPlans AS TT_SubscriptionPlans
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubscriptionPlansInventory.Ref AS Ref,
		|	SubscriptionPlansInventory.LineNumber AS LineNumber,
		|	SubscriptionPlansInventory.Products AS Products,
		|	SubscriptionPlansInventory.Characteristic AS Characteristic,
		|	SubscriptionPlansInventory.Content AS Content,
		|	SubscriptionPlansInventory.Quantity AS Quantity,
		|	SubscriptionPlansInventory.MeasurementUnit AS MeasurementUnit,
		|	SubscriptionPlansInventory.Price AS Price,
		|	SubscriptionPlansInventory.Batch AS Batch
		|INTO TT_SubscriptionPlansInventory
		|FROM
		|	Catalog.SubscriptionPlans.Inventory AS SubscriptionPlansInventory
		|WHERE
		|	SubscriptionPlansInventory.Ref = &SubscriptionPlan
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubscriptionPlansInventory.Products AS Products,
		|	SubscriptionPlansInventory.Content AS Content,
		|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
		|	SubscriptionPlansInventory.Quantity AS Quantity,
		|	SubscriptionPlansInventory.MeasurementUnit AS MeasurementUnit,
		|	ISNULL(UOM.Factor, 1) AS Factor,
		|	ProductsCatalog.InventoryGLAccount AS InventoryGLAccount,
		|	CASE
		|		WHEN ProductsCatalog.VATRate = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN TT_VAT.VATRate
		|		ELSE ProductsCatalog.VATRate
		|	END AS VATRate,
		|	SubscriptionPlansInventory.Price AS Price,
		|	SubscriptionPlansInventory.Quantity * SubscriptionPlansInventory.Price AS Amount,
		|	&ReceiptDate AS ReceiptDate,
		|	ProductsCatalog.ProductsType AS ProductsType,
		|	SubscriptionPlansInventory.Batch AS Batch
		|FROM
		|	TT_SubscriptionPlansInventory AS SubscriptionPlansInventory
		|		INNER JOIN TT_VAT AS TT_VAT
		|		ON SubscriptionPlansInventory.Ref = TT_VAT.Subscription
		|		INNER JOIN Catalog.Products AS ProductsCatalog
		|		ON SubscriptionPlansInventory.Products = ProductsCatalog.Ref
		|		LEFT JOIN Catalog.UOM AS UOM
		|		ON SubscriptionPlansInventory.MeasurementUnit = UOM.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_SubscriptionPlans.Subscription AS Subscription,
		|	TT_SubscriptionPlans.Subscription AS Schedule,
		|	TT_SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	TT_SubscriptionPlans.Date AS Date,
		|	TT_SubscriptionPlans.Company AS Company,
		|	TT_SubscriptionPlans.ActionOnCreating AS ActionOnCreating,
		|	TT_SubscriptionPlans.VATRate AS VATRate,
		|	TT_SubscriptionPlans.Counterparty AS Counterparty,
		|	TT_SubscriptionPlans.Contract AS Contract,
		|	TT_SubscriptionPlans.DocumentCurrency AS DocumentCurrency,
		|	TT_SubscriptionPlans.PriceKind AS PriceKind,
		|	TT_SubscriptionPlans.Department AS Department,
		|	TT_SubscriptionPlans.PriceKind.PriceIncludesVAT = TRUE AS AmountIncludesVAT,
		|	TT_SubscriptionPlans.EmailTo AS EmailTo,
		|	VALUE(Catalog.BusinessUnits.MainWarehouse) AS StructuralUnit,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Rate, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Rate, 1)
		|	END AS ExchangeRate,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Repetition, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Repetition, 1)
		|	END AS Multiplicity,
		|	CASE
		|		WHEN TT_SubscriptionPlans.CounterpartyVATTaxation <> VALUE(Enum.VATTaxationTypes.EmptyRef)
		|				AND (NOT TT_SubscriptionPlans.CompanyVATTaxation = VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ForExport))
		|			THEN TT_SubscriptionPlans.CounterpartyVATTaxation
		|		ELSE TT_SubscriptionPlans.CompanyVATTaxation
		|	END AS VATTaxation,
		|	&ReceiptDate AS ReceiptDate,
		|	GeneratedDocumentsData.PlannedDate AS PlannedDate,
		|	TT_SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	TT_SubscriptionPlans.CompanyVATNumber AS CompanyVATNumber,
		|	TT_SubscriptionPlans.ScheduledJobUUID AS ScheduledJobUUID
		|FROM
		|	TT_SubscriptionPlans AS TT_SubscriptionPlans
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
		|		ON TT_SubscriptionPlans.Company = ExchangeRateSliceLast.Company
		|			AND TT_SubscriptionPlans.DocumentCurrency = ExchangeRateSliceLast.Currency
		|		INNER JOIN InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
		|		ON TT_SubscriptionPlans.Subscription = GeneratedDocumentsData.SubscriptionPlan
		|			AND TT_SubscriptionPlans.Counterparty <> GeneratedDocumentsData.Counterparty
		|			AND TT_SubscriptionPlans.Contract <> GeneratedDocumentsData.Contract
		|			AND (GeneratedDocumentsData.ActualDate = DATETIME(1, 1, 1))
		|WHERE
		|	GeneratedDocumentsData.PlannedDate <= &DocumentDate";
		
		StructureQueryData.NumberHeader		= 5;
		StructureQueryData.NumberInventory	= 4;
		
	Else 
		
		StructureQueryData.QueryText = 
		"SELECT ALLOWED
		|	Subscriptions.SubscriptionPlan AS SubscriptionPlan,
		|	Subscriptions.Counterparty AS Counterparty,
		|	Subscriptions.Contract AS Contract,
		|	Subscriptions.EmailTo AS EmailTo,
		|	Subscriptions.StartDate AS StartDate,
		|	Subscriptions.EndDate AS EndDate
		|INTO TT_Subscriptions
		|FROM
		|	InformationRegister.Subscriptions AS Subscriptions
		|WHERE
		|	Subscriptions.SubscriptionPlan = &SubscriptionPlan
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesInvoice.Ref AS Ref,
		|	SalesInvoice.Counterparty AS Counterparty,
		|	SalesInvoice.Contract AS Contract,
		|	SalesInvoice.Date AS Date
		|INTO TT_Documents
		|FROM
		|	TT_Subscriptions AS Subscriptions
		|		INNER JOIN Document.SalesInvoice AS SalesInvoice
		|		ON (&IsSalesInvoice)
		|			AND (NOT SalesInvoice.DeletionMark)
		|			AND Subscriptions.SubscriptionPlan = SalesInvoice.Subscription
		|			AND Subscriptions.Counterparty = SalesInvoice.Counterparty
		|			AND Subscriptions.Contract = SalesInvoice.Contract
		|
		|UNION ALL
		|
		|SELECT
		|	PurchaseOrder.Ref,
		|	PurchaseOrder.Counterparty,
		|	PurchaseOrder.Contract,
		|	PurchaseOrder.Date
		|FROM
		|	TT_Subscriptions AS Subscriptions
		|		INNER JOIN Document.PurchaseOrder AS PurchaseOrder
		|		ON (&IsPurchaseOrder)
		|			AND (NOT PurchaseOrder.DeletionMark)
		|			AND Subscriptions.SubscriptionPlan = PurchaseOrder.Schedule
		|			AND Subscriptions.Counterparty = PurchaseOrder.Counterparty
		|			AND Subscriptions.Contract = PurchaseOrder.Contract
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoice.Ref,
		|	SupplierInvoice.Counterparty,
		|	SupplierInvoice.Contract,
		|	SupplierInvoice.Date
		|FROM
		|	TT_Subscriptions AS Subscriptions
		|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
		|		ON (&IsSupplierInvoice)
		|			AND (NOT SupplierInvoice.DeletionMark)
		|			AND Subscriptions.SubscriptionPlan = SupplierInvoice.Schedule
		|			AND Subscriptions.Counterparty = SupplierInvoice.Counterparty
		|			AND Subscriptions.Contract = SupplierInvoice.Contract
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubscriptionPlans.Ref AS Subscription,
		|	SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	&DocumentDate AS Date,
		|	SubscriptionPlans.Company AS Company,
		|	SubscriptionPlans.ActionOnCreating AS ActionOnCreating,
		|	SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	CASE
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Day)
		|			THEN BEGINOFPERIOD(&DocumentDate, DAY)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Month)
		|			THEN BEGINOFPERIOD(&DocumentDate, MONTH)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Year)
		|			THEN BEGINOFPERIOD(&DocumentDate, YEAR)
		|	END AS BeginOfChargePeriod,
		|	CASE
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Day)
		|			THEN ENDOFPERIOD(&DocumentDate, DAY)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Month)
		|			THEN ENDOFPERIOD(&DocumentDate, MONTH)
		|		WHEN SubscriptionPlans.ChargeFrequency = VALUE(Enum.Periodicity.Year)
		|			THEN ENDOFPERIOD(&DocumentDate, YEAR)
		|	END AS EndOfChargePeriod,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.DefaultVATRate, VALUE(Catalog.VATRates.EmptyRef)) = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN VALUE(Catalog.VATRates.Exempt)
		|		ELSE AccountingPolicySliceLast.DefaultVATRate
		|	END AS VATRate,
		|	Subscriptions.Counterparty AS Counterparty,
		|	Subscriptions.Contract AS Contract,
		|	Subscriptions.EmailTo AS EmailTo,
		|	CASE
		|		WHEN Subscriptions.Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|				OR Subscriptions.Contract.SettlementsCurrency = VALUE(Catalog.Currencies.EmptyRef)
		|			THEN FunctionalCurrency.Value
		|		ELSE Subscriptions.Contract.SettlementsCurrency
		|	END AS DocumentCurrency,
		|	CASE
		|		WHEN Subscriptions.Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|				OR Subscriptions.Contract.PriceKind = VALUE(Catalog.PriceTypes.EmptyRef)
		|			THEN CASE
		|					WHEN Subscriptions.Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
		|							OR Subscriptions.Counterparty.PriceKind = VALUE(Catalog.PriceTypes.EmptyRef)
		|						THEN VALUE(Catalog.PriceTypes.Wholesale)
		|					ELSE Subscriptions.Counterparty.PriceKind
		|				END
		|		ELSE Subscriptions.Contract.PriceKind
		|	END AS PriceKind,
		|	CASE
		|		WHEN Subscriptions.Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|				OR Subscriptions.Contract.Department = VALUE(Catalog.BusinessUnits.EmptyRef)
		|			THEN VALUE(Catalog.BusinessUnits.MainDepartment)
		|		ELSE Subscriptions.Contract.Department
		|	END AS Department,
		|	CASE
		|		WHEN ISNULL(AccountingPolicySliceLast.RegisteredForVAT, FALSE)
		|			THEN VALUE(Enum.VATTaxationTypes.SubjectToVAT)
		|		ELSE VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|	END AS CompanyVATTaxation,
		|	Subscriptions.Counterparty.VATTaxation AS CounterpartyVATTaxation,
		|	Companies.VATNumber AS CompanyVATNumber,
		|	SubscriptionPlans.ScheduledJobUUID AS ScheduledJobUUID
		|INTO TT_SubscriptionPlans
		|FROM
		|	Catalog.SubscriptionPlans AS SubscriptionPlans
		|		INNER JOIN TT_Subscriptions AS Subscriptions
		|		ON SubscriptionPlans.Ref = Subscriptions.SubscriptionPlan
		|			AND (&DocumentDate >= Subscriptions.StartDate)
		|			AND (SubscriptionPlans.Enabled)
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&DocumentDate, ) AS AccountingPolicySliceLast
		|		ON SubscriptionPlans.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON SubscriptionPlans.Company = Companies.Ref,
		|	Constant.FunctionalCurrency AS FunctionalCurrency
		|WHERE
		|	CASE
		|			WHEN Subscriptions.EndDate = DATETIME(1, 1, 1)
		|				THEN TRUE
		|			ELSE BEGINOFPERIOD(&DocumentDate, DAY) <= Subscriptions.EndDate
		|		END
		|
		|INDEX BY
		|	BeginOfChargePeriod,
		|	EndOfChargePeriod,
		|	Subscription,
		|	Counterparty,
		|	Contract
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_SubscriptionPlans.Subscription AS Subscription,
		|	TT_SubscriptionPlans.VATRate AS VATRate
		|INTO TT_VAT
		|FROM
		|	TT_SubscriptionPlans AS TT_SubscriptionPlans
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubscriptionPlansInventory.Ref AS Ref,
		|	SubscriptionPlansInventory.LineNumber AS LineNumber,
		|	SubscriptionPlansInventory.Products AS Products,
		|	SubscriptionPlansInventory.Characteristic AS Characteristic,
		|	SubscriptionPlansInventory.Content AS Content,
		|	SubscriptionPlansInventory.Quantity AS Quantity,
		|	SubscriptionPlansInventory.MeasurementUnit AS MeasurementUnit,
		|	SubscriptionPlansInventory.Price AS Price,
		|	SubscriptionPlansInventory.Batch AS Batch
		|INTO TT_SubscriptionPlansInventory
		|FROM
		|	Catalog.SubscriptionPlans.Inventory AS SubscriptionPlansInventory
		|WHERE
		|	SubscriptionPlansInventory.Ref = &SubscriptionPlan
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubscriptionPlansInventory.Products AS Products,
		|	SubscriptionPlansInventory.Content AS Content,
		|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
		|	SubscriptionPlansInventory.Quantity AS Quantity,
		|	SubscriptionPlansInventory.MeasurementUnit AS MeasurementUnit,
		|	ISNULL(UOM.Factor, 1) AS Factor,
		|	ProductsCatalog.InventoryGLAccount AS InventoryGLAccount,
		|	CASE
		|		WHEN ProductsCatalog.VATRate = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN TT_VAT.VATRate
		|		ELSE ProductsCatalog.VATRate
		|	END AS VATRate,
		|	SubscriptionPlansInventory.Price AS Price,
		|	SubscriptionPlansInventory.Quantity * SubscriptionPlansInventory.Price AS Amount,
		|	&ReceiptDate AS ReceiptDate,
		|	ProductsCatalog.ProductsType AS ProductsType,
		|	SubscriptionPlansInventory.Batch AS Batch
		|FROM
		|	TT_SubscriptionPlansInventory AS SubscriptionPlansInventory
		|		INNER JOIN TT_VAT AS TT_VAT
		|		ON SubscriptionPlansInventory.Ref = TT_VAT.Subscription
		|		INNER JOIN Catalog.Products AS ProductsCatalog
		|		ON SubscriptionPlansInventory.Products = ProductsCatalog.Ref
		|		LEFT JOIN Catalog.UOM AS UOM
		|		ON SubscriptionPlansInventory.MeasurementUnit = UOM.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_SubscriptionPlans.Subscription AS Subscription,
		|	TT_SubscriptionPlans.Subscription AS Schedule,
		|	TT_SubscriptionPlans.TypeOfDocument AS TypeOfDocument,
		|	TT_SubscriptionPlans.Date AS Date,
		|	TT_SubscriptionPlans.Company AS Company,
		|	TT_SubscriptionPlans.ActionOnCreating AS ActionOnCreating,
		|	TT_SubscriptionPlans.ChargeFrequency AS ChargeFrequency,
		|	TT_SubscriptionPlans.VATRate AS VATRate,
		|	TT_SubscriptionPlans.Counterparty AS Counterparty,
		|	TT_SubscriptionPlans.Contract AS Contract,
		|	TT_SubscriptionPlans.DocumentCurrency AS DocumentCurrency,
		|	TT_SubscriptionPlans.PriceKind AS PriceKind,
		|	TT_SubscriptionPlans.Department AS Department,
		|	TT_SubscriptionPlans.PriceKind.PriceIncludesVAT = TRUE AS AmountIncludesVAT,
		|	TT_SubscriptionPlans.EmailTo AS EmailTo,
		|	VALUE(Catalog.BusinessUnits.MainWarehouse) AS StructuralUnit,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Rate, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Rate, 1)
		|	END AS ExchangeRate,
		|	CASE
		|		WHEN ISNULL(ExchangeRateSliceLast.Repetition, 1) = 0
		|			THEN 1
		|		ELSE ISNULL(ExchangeRateSliceLast.Repetition, 1)
		|	END AS Multiplicity,
		|	CASE
		|		WHEN TT_SubscriptionPlans.CounterpartyVATTaxation <> VALUE(Enum.VATTaxationTypes.EmptyRef)
		|				AND (NOT TT_SubscriptionPlans.CompanyVATTaxation = VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|					OR TT_SubscriptionPlans.CounterpartyVATTaxation = VALUE(Enum.VATTaxationTypes.ForExport))
		|			THEN TT_SubscriptionPlans.CounterpartyVATTaxation
		|		ELSE TT_SubscriptionPlans.CompanyVATTaxation
		|	END AS VATTaxation,
		|	&ReceiptDate AS ReceiptDate,
		|	TT_SubscriptionPlans.CompanyVATNumber AS CompanyVATNumber,
		|	TT_SubscriptionPlans.ScheduledJobUUID AS ScheduledJobUUID
		|FROM
		|	TT_SubscriptionPlans AS TT_SubscriptionPlans
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
		|		ON TT_SubscriptionPlans.Company = ExchangeRateSliceLast.Company
		|			AND TT_SubscriptionPlans.DocumentCurrency = ExchangeRateSliceLast.Currency
		|		LEFT JOIN TT_Documents AS TT_Documents
		|		ON TT_SubscriptionPlans.BeginOfChargePeriod <= TT_Documents.Date
		|			AND TT_SubscriptionPlans.EndOfChargePeriod >= TT_Documents.Date
		|			AND TT_SubscriptionPlans.Counterparty = TT_Documents.Counterparty
		|			AND TT_SubscriptionPlans.Contract = TT_Documents.Contract
		|WHERE
		|	TT_Documents.Ref IS NULL";
		
		StructureQueryData.NumberHeader		= 6;
		StructureQueryData.NumberInventory	= 5;
		
	EndIf;
	
	Return StructureQueryData;
	
EndFunction

Function GetPurchaseOrderstate(OrderState)
	
	If Constants.UsePurchaseOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewPurchaseOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.PurchaseOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.PurchaseOrdersInProgressStatus.Get();
	EndIf;
	
	Return OrderState;
	
EndFunction

Function GenerateCommentBySubscriptionPlan(SubscriptionPlan, TypeOfDocument)
	
	If TypeOfDocument = "SupplierInvoice" Then
		
		ObjectPresentation = NStr("en = 'supplier invoice schedule'; ru = 'график инвойса поставщика';pl = 'harmonogram faktury zakupu';es_ES = 'horario de factura de compra';es_CO = 'horario de factura de compra';tr = 'satın alma faturası programı';it = 'fattura di acquisto programma';de = 'lieferantenrechnungszeitplan'");
		
	ElsIf TypeOfDocument = "PurchaseOrder" Then
		
		ObjectPresentation = NStr("en = 'purchase order schedule'; ru = 'график заказов поставщику';pl = 'harmonogram zamówień zakupu';es_ES = 'horario de la orden de compra';es_CO = 'horario de la orden de compra';tr = 'satın alma siparişi planı';it = 'pianificazione ordini di produzione';de = 'zeitplan für bestellung an lieferanten'");
		
	Else 
		
		ObjectPresentation = NStr("en = 'subscription plan'; ru = 'план подписки';pl = 'plan subskrypcji';es_ES = 'plan de suscripción';es_CO = 'plan de suscripción';tr = 'abonelik planı';it = 'piano di abbonamento';de = 'Abonnement-Plan'");
		
	EndIf;
	
	If Not IsBlankString(ObjectPresentation) Then
		ObjectPresentation = "(" + ObjectPresentation + ")";
	EndIf;
	
	Comment = NStr("en = 'Created automatically by %1 %2'; ru = 'Автоматически создано %1 %2';pl = 'Stworzono automatycznie zgodnie z %1 %2';es_ES = 'Creado automáticamente por %1 %2';es_CO = 'Creado automáticamente por %1 %2';tr = '%1 %2 tarafından otomatik olarak oluşturuldu';it = 'Creato automaticamente da %1 %2';de = 'Automatisch erstellt von %1 %2'");
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		Comment, SubscriptionPlan, ObjectPresentation);
		
EndFunction

Procedure WriteGeneratedDocumentsData(Selection, StructureData, ValueListDatesToDelete = Undefined, PlannedDate = Undefined)
	
	RecordManagerSchedule = InformationRegisters.GeneratedDocumentsData.CreateRecordManager();
	
	RecordManagerSchedule.PlannedDate		= ?(ValueIsFilled(PlannedDate), PlannedDate, Selection.PlannedDate);
	RecordManagerSchedule.SubscriptionPlan	= StructureData.SubscriptionPlan;
	RecordManagerSchedule.ActualDate		= StructureData.DocumentDate;
	RecordManagerSchedule.Counterparty		= Selection.Counterparty;
	RecordManagerSchedule.Contract			= Selection.Contract;
	
	If ValueListDatesToDelete <> Undefined
		And ValueListDatesToDelete.FindByValue(Selection.PlannedDate) = Undefined Then
		ValueListDatesToDelete.Add(Selection.PlannedDate);
	EndIf;
	
	RecordManagerSchedule.Write();
	
EndProcedure

Procedure DeleteRecordsGeneratedDocumentsData(ValueListDatesToDelete, StructureData)
	
	For Each ItemValueList In ValueListDatesToDelete Do
		
		RecordSetSchedule = InformationRegisters.GeneratedDocumentsData.CreateRecordSet();
		
		RecordSetSchedule.Filter.SubscriptionPlan.Set(StructureData.SubscriptionPlan);
		RecordSetSchedule.Filter.PlannedDate.Set(ItemValueList.Value);
		RecordSetSchedule.Filter.ActualDate.Set(Date(1, 1, 1));
		RecordSetSchedule.Filter.Counterparty.Set(Catalogs.Counterparties.EmptyRef());
		RecordSetSchedule.Filter.Contract.Set(Catalogs.CounterpartyContracts.EmptyRef());
		
		RecordSetSchedule.Write();
		
	EndDo;
	
EndProcedure

Function GetPlannedDate(Selection) Export
	
	Result = Selection.Date;
	
	If Selection.ChargeFrequency = Enums.Periodicity.Month Then
	
		DaysCounter = BegOfMonth(Result);
		EndOfDays = EndOfMonth(Result);
		
	ElsIf Selection.ChargeFrequency = Enums.Periodicity.Year Then
		
		DaysCounter = BegOfYear(Result);
		EndOfDays = EndOfYear(Result);	
		
	EndIf;
	
	If Selection.ChargeFrequency = Enums.Periodicity.Month 
		Or Selection.ChargeFrequency = Enums.Periodicity.Year Then
		
		While DaysCounter <= EndOfDays Do
			
			If ScheduledJobs.FindByUUID(Selection.ScheduledJobUUID).Schedule.ExecutionRequired(DaysCounter) Then
				
				Result = DaysCounter;
				Break;
				
			EndIf; 
			
			DaysCounter = DaysCounter + 86400;
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
