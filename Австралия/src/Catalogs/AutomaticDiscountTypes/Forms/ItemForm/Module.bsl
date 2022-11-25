#Region CommonProceduresAndFunctions

// The procedure updates the name if the user did not change it manually.
//
&AtClient
Procedure UpdateAutoNaming(Refresh = True, SetModified = False)
	
	If Not ValueIsFilled(Object.Description) OR (Refresh AND UsedAutoDescription AND Not DescriptionChangedByUser) Then
		Object.Description = FormAutoNamingAtClient();
		UsedAutoDescription = True;
		
		If SetModified Then
			Modified = True;
		EndIf;
	EndIf;
	
EndProcedure

// The function returns generated auto naming.
//
&AtClient
Function FormAutoNamingAtClient()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = "";
	
	If Object.AssignmentMethod = AssignmentMethodPercent Then
		
		DescriptionString = "" + Object.DiscountMarkupValue + NStr("en = '%'; ru = '%';pl = '%';es_ES = '%';es_CO = '%';tr = '%';it = '%';de = '%'");
		
	ElsIf Object.AssignmentMethod = AssignmentMethodAmount Then
		
		DescriptionString = "" + Object.DiscountMarkupValue + " " + Object.AssignmentCurrency;
		
	EndIf;
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	If Object.ConditionsOfAssignment.Count() = 1 Then
		DescriptionString = DescriptionString + " ("+Object.ConditionsOfAssignment[0].AssignmentCondition+")";
		Items.Description.ChoiceList.Add(DescriptionString);
	ElsIf Object.ConditionsOfAssignment.Count() > 1 Then
		
		ConditionsNumber = Object.ConditionsOfAssignment.Count();
		
		If ConditionsNumber >= 2 Then
			DescriptionString = DescriptionString + " " +NStr("en = '(several conditions)'; ru = '(несколько условий)';pl = '(kilka warunków)';es_ES = '(varias condiciones)';es_CO = '(varias condiciones)';tr = '(birkaç koşul)';it = '(diverse condizioni)';de = '(mehrere Bedingungen)'");
			Items.Description.ChoiceList.Add(DescriptionString);
		EndIf;
		
	ElsIf Object.ConditionsOfAssignment.Count() = 0 Then
		DescriptionString = DescriptionString + " " + NStr("en = 'without conditions'; ru = 'без условий';pl = 'bez warunków';es_ES = 'sin condiciones';es_CO = 'sin condiciones';tr = 'koşulsuz';it = 'senza condizioni';de = 'ohne Bedingungen'");
		Items.Description.ChoiceList.Add(DescriptionString);
	EndIf;
	
	AmountInDocument = (Object.AssignmentMethod = AssignmentMethodAmount AND Object.AssignmentArea = AreaInDocument);
	If Object.ProductsGroupsPriceGroups.Count() > 0 AND Not AmountInDocument Then
		DescriptionString = DescriptionString + NStr("en = ', with details'; ru = ', с реквизитами';pl = ', ze szczegółami';es_ES = ', con detalles';es_CO = ', con detalles';tr = ', ayrıntılarla';it = ', con dettagli';de = ', mit Details'");
		Items.Description.ChoiceList.Add(DescriptionString);
	EndIf;
	
	If (Object.DiscountRecipientsCounterparties.Count() > 0 AND Object.Purpose <> PurposeRetail) 
		OR (Object.DiscountRecipientsWarehouses.Count() > 0 AND Object.Purpose <> PurposeWholesale) Then
		DescriptionString = DescriptionString + NStr("en = ', for certain customers'; ru = ', указаны получатели';pl = ', dla niektórych nabywców';es_ES = ', para algunos clientes';es_CO = ', para algunos clientes';tr = ', belirli müşteriler için';it = ', per alcuni clienti';de = ', für bestimmte Kunden'");
		Items.Description.ChoiceList.Add(DescriptionString);
	EndIf;
	
	If Object.TimeByDaysOfWeek.Count() > 0 Then
		DescriptionString = DescriptionString + NStr("en = ', on weekly schedule'; ru = ', по расписанию';pl = ', w harmonogramie tygodniowym';es_ES = ', en horario semanal';es_CO = ', en horario semanal';tr = ', haftalık programa göre';it = ', nella pianificazione settimanale';de = ', auf Wochenplan'");
		Items.Description.ChoiceList.Add(DescriptionString);
	EndIf;
	
	Return DescriptionString;

EndFunction

// The function returns generated auto naming.
//
&AtServer
Function FormAutoNamingAtServer()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = "";
	
	If Object.AssignmentMethod = AssignmentMethodPercent Then
		
		DescriptionString = "" + Object.DiscountMarkupValue + NStr("en = '%'; ru = '%';pl = '%';es_ES = '%';es_CO = '%';tr = '%';it = '%';de = '%'");
		
	ElsIf Object.AssignmentMethod = AssignmentMethodAmount Then
		
		DescriptionString = "" + Object.DiscountMarkupValue + " " + Object.AssignmentCurrency;
		
	EndIf;
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	If Object.ConditionsOfAssignment.Count() = 1 Then
		
		DescriptionString = DescriptionString + " ("+Object.ConditionsOfAssignment[0].AssignmentCondition+")";
		Items.Description.ChoiceList.Add(DescriptionString);
		
	ElsIf Object.ConditionsOfAssignment.Count() > 1 Then
		
		ConditionsNumber = Object.ConditionsOfAssignment.Count();
		
		If ConditionsNumber >= 2 Then
			DescriptionString = DescriptionString + " " +NStr("en = '(several conditions)'; ru = '(несколько условий)';pl = '(kilka warunków)';es_ES = '(varias condiciones)';es_CO = '(varias condiciones)';tr = '(birkaç koşul)';it = '(diverse condizioni)';de = '(mehrere Bedingungen)'");
			Items.Description.ChoiceList.Add(DescriptionString);
		EndIf;
		
	ElsIf Object.ConditionsOfAssignment.Count() = 0 Then
		
		DescriptionString = DescriptionString + " " + NStr("en = 'without conditions'; ru = 'без условий';pl = 'bez warunków';es_ES = 'sin condiciones';es_CO = 'sin condiciones';tr = 'koşulsuz';it = 'senza condizioni';de = 'ohne Bedingungen'");
		Items.Description.ChoiceList.Add(DescriptionString);
		
	EndIf;
	
	AmountInDocument = (Object.AssignmentMethod = AssignmentMethodAmount AND Object.AssignmentArea = AreaInDocument);
	If Object.ProductsGroupsPriceGroups.Count() > 0 AND Not AmountInDocument Then
		DescriptionString = DescriptionString + NStr("en = ', with specification'; ru = ', с уточнением';pl = ', ze specyfikacją';es_ES = ', con especificación';es_CO = ', con especificación';tr = ', şartname ile';it = ', con le specifiche';de = ', mit Spezifikation'");
		Items.Description.ChoiceList.Add(DescriptionString);
	EndIf;
	
	If (Object.DiscountRecipientsCounterparties.Count() > 0 AND Object.Purpose <> PurposeRetail) 
		OR (Object.DiscountRecipientsWarehouses.Count() > 0 AND Object.Purpose <> PurposeWholesale) Then
		DescriptionString = DescriptionString + NStr("en = ', recipients are specified'; ru = ', указаны получатели';pl = ', odbiorcy są określeni';es_ES = ', destinatarios están especificados';es_CO = ', destinatarios están especificados';tr = ', alıcılar belirlendi';it = ', sono specificati i destinatari';de = ', Empfänger sind angegeben'");
		Items.Description.ChoiceList.Add(DescriptionString);
	EndIf;
	
	If Object.TimeByDaysOfWeek.Count() > 0 Then
		DescriptionString = DescriptionString + NStr("en = ', on schedule'; ru = ', по расписанию';pl = ', według harmonogramu';es_ES = ', a tiempo programado';es_CO = ', a tiempo programado';tr = ', zamanında';it = ', in orario';de = ', nach Plan'");
		Items.Description.ChoiceList.Add(DescriptionString);
	EndIf;
	
	Return DescriptionString;

EndFunction

// The function returns an option for shared use of automatic discounts which is relevant to the current discount.
//
&AtServerNoContext
Function GetSharedUsageCurrentOption(Parent)

	If Parent.IsEmpty() Then
		Return Constants.DefaultDiscountsApplyingRule.Get();
	Else
		Return Parent.SharedUsageVariant;
	EndIf;

EndFunction

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// To reduce the number of non-contextual calls to server.
	AssignmentMethodPercent = Enums.DiscountValueType.Percent;
	AssignmentMethodAmount = Enums.DiscountValueType.Amount;
	RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProducts;
	RestrictionVariantByProductsGroups = Enums.DiscountApplyingFilterType.ByProductsCategories;
	VariantRestrictionByPriceGroups = Enums.DiscountApplyingFilterType.ByPriceGroups;
	RestrictionVariantByProductsSegments = Enums.DiscountApplyingFilterType.ByProductsSegments;
	PurposeRetail = Enums.DiscountsArea.Retail;
	PurposeWholesale = Enums.DiscountsArea.Wholesale;
	AreaInDocument = Enums.DiscountApplyingArea.InDocument;
	
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	ReadOnly = Not AllowedEditDocumentPrices;
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.Description = FormAutoNamingAtServer();
	Else
		FormAutoNamingAtServer();
	EndIf;
	
	For Each NameVariant In Items.Description.ChoiceList Do
		If Object.Description = NameVariant.Value Then
			UsedAutoDescription = True;
			Break;
		EndIf;
	EndDo;
	
	// Define visible of attribute for additional sorting.
	If Object.AdditionalOrderingAttribute > 0 Then
		Items.AdditionalOrderingAttribute.Visible = True;
	Else
		If Object.Parent.IsEmpty() Then
			SharedUsageCurOption = Constants.DefaultDiscountsApplyingRule.Get();
		Else
			SharedUsageCurOption = Object.Parent.SharedUsageVariant;
		EndIf;
		
		Items.AdditionalOrderingAttribute.Visible = (SharedUsageCurOption = Enums.DiscountsApplyingRules.Exclusion 
														OR SharedUsageCurOption = Enums.DiscountsApplyingRules.Multiplication);
	EndIf;
	
	RestrictionByProductsVariantBeforeChange = Object.RestrictionByProductsVariant;
	Items.DecorationParentSharedUsageVariant.Title = String(Object.Parent.SharedUsageVariant);
	Items.DecorationParentSharedUsageVariant.Visible = Not Object.Parent.IsEmpty();
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	VisibleManagementAtServer();
	
EndProcedure

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AssignmentCondition_Record" Then
		UpdateAutoNaming(True, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.ConditionsOfAssignment.Count() = 1
		And Object.ConditionsOfAssignment[0].AssignmentCondition = PredefinedValue("Catalog.DiscountConditions.EmptyRef") Then
			Object.ConditionsOfAssignment.Delete(0);
			UpdateAutoNaming(True);
	EndIf;
		
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// The procedure controls the visible of items depending on restriction option, method and area of discount application.
//
&AtServer
Procedure VisibleManagementAtServer()

	If Object.RestrictionByProductsVariant.IsEmpty() Then
		Object.RestrictionByProductsVariant = RestrictionByProductsVariant;
	EndIf;
	
	AmountInDocument = (Object.AssignmentMethod = AssignmentMethodAmount 
						AND Object.AssignmentArea = AreaInDocument);
		
	Items.Clarification.Visible = Not AmountInDocument;
	If Object.RestrictionByProductsVariant = RestrictionByProductsVariant Then
		Items.ProductsGroupsPriceGroupsClarificationValue.Title = NStr("en = 'Products'; ru = 'Номенклатура';pl = 'Produkty';es_ES = 'Productos';es_CO = 'Productos';tr = 'Ürünler';it = 'Articoli';de = 'Produkte'");
		Items.ProductsGroupsPriceGroupsClarificationValue.TypeRestriction = New TypeDescription("CatalogRef.Products");
		Items.ProductsGroupsPriceGroupsCharacteristic.Visible = True;
	ElsIf Object.RestrictionByProductsVariant = RestrictionVariantByProductsGroups Then
		Items.ProductsGroupsPriceGroupsClarificationValue.TypeRestriction = New TypeDescription("CatalogRef.ProductsCategories");
		Items.ProductsGroupsPriceGroupsClarificationValue.Title = NStr("en = 'Product category'; ru = 'Категория номенклатуры';pl = 'Kategoria produktu';es_ES = 'Categoría de producto';es_CO = 'Categoría de producto';tr = 'Ürün kategorisi';it = 'Categoria articolo';de = 'Produktkategorie'");
		Items.ProductsGroupsPriceGroupsCharacteristic.Visible = False;
	ElsIf Object.RestrictionByProductsVariant = VariantRestrictionByPriceGroups Then
		Items.ProductsGroupsPriceGroupsClarificationValue.Title = NStr("en = 'Price group'; ru = 'Ценовая группа';pl = 'Grupa cenowa';es_ES = 'Grupo de precios';es_CO = 'Grupo de precios';tr = 'Fiyat grubu';it = 'Gruppo di prezzo';de = 'Preisgruppe'");
		Items.ProductsGroupsPriceGroupsClarificationValue.TypeRestriction = New TypeDescription("CatalogRef.PriceGroups");
		Items.ProductsGroupsPriceGroupsCharacteristic.Visible = False;
	ElsIf Object.RestrictionByProductsVariant = RestrictionVariantByProductsSegments Then
		Items.ProductsGroupsPriceGroupsClarificationValue.Title = NStr("en = 'Segments'; ru = 'Сегменты';pl = 'Segmenty';es_ES = 'Segmentos';es_CO = 'Segmentos';tr = 'Segmentler';it = 'Segmenti';de = 'Segmente'");
		Items.ProductsGroupsPriceGroupsClarificationValue.TypeRestriction = New TypeDescription("CatalogRef.ProductSegments");
		Items.ProductsGroupsPriceGroupsCharacteristic.Visible = False;
	EndIf;
	
	Items.AssignmentArea.Visible = (Object.AssignmentMethod = Enums.DiscountValueType.Amount);
	Items.AssignmentCurrency.Visible = (Object.AssignmentMethod = AssignmentMethodAmount);
	
	RecipientsVisibleSetupAtServer();
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item RestrictionByProductsOption.
//
&AtClient
Procedure RestrictionByProductsVariantOnChange(Item)
	
	If Object.ProductsGroupsPriceGroups.Count() > 0 Then
		Description = New NotifyDescription("RestrictionByProductsOptionOnChangeConclusion", ThisObject);
		ShowQueryBox(Description, NStr("en = 'Table of refinements will be cleared. Continue?'; ru = 'Таблица уточнений будет очищена. Продолжить?';pl = 'Tabela uściśleń zostanie wyczyszczona. Kontynuować?';es_ES = 'Tabla de refinamientos se eliminará. ¿Continuar?';es_CO = 'Tabla de refinamientos se eliminará. ¿Continuar?';tr = 'Düzeltmeler tablosu silinecek. Devam edilsin mi?';it = 'La tabella di precisazioni verrà cancellata. Volete continuare?';de = 'Tabelle der Verfeinerungen wird gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo,,DialogReturnCode.No,"Change refining option");
	Else
		RestrictionByProductsVariantBeforeChange = Object.RestrictionByProductsVariant;
		VisibleManagementAtServer();
	EndIf;
	
EndProcedure

// Procedure - events handler OnChange item RestrictionByProductsOption (conclusion after response to the question about deletion of lines in SP).
//
&AtClient
Procedure RestrictionByProductsOptionOnChangeConclusion(ResponseResult, AdditionalParameters) Export

	If ResponseResult <> DialogReturnCode.Yes Then
		Object.RestrictionByProductsVariant = RestrictionByProductsVariantBeforeChange;
		Return;
	EndIf;
	
	Object.ProductsGroupsPriceGroups.Clear();
	RestrictionByProductsVariantBeforeChange = Object.RestrictionByProductsVariant;
	VisibleManagementAtServer();
	
	UpdateAutoNaming(True);
	
EndProcedure

// Procedure - event handler OnChange item ProvisionMethod.
//
&AtClient
Procedure AssignmentMethodOnChange(Item)
	
	VisibleManagementAtServer();
	Object.DiscountMarkupValue = 0;
	
	ShowClarificationsPage = False;
	For Each CurrentRow In Object.ProductsGroupsPriceGroups Do
		ShowClarificationsPage = True;
	EndDo;
	
	If ShowClarificationsPage Then
		
		Items.Pages.CurrentPage = Items.GroupClarificationsRestrictionsAndSchedule;
		Items.PagesClarificationsAndRestrictions.CurrentPage = Items.Clarification;
		
		AmountInDocument = (Object.AssignmentMethod = AssignmentMethodAmount 
							AND Object.AssignmentArea = AreaInDocument);
							
		If Not AmountInDocument Then
			CommonClientServer.MessageToUser(NStr("en = 'Discounts are cleared'; ru = 'Скидки удалены';pl = 'Rabaty rozliczone';es_ES = 'Descuentos se han liquidados';es_CO = 'Descuentos se han liquidados';tr = 'İndirimler temizlendi';it = 'Gli sconti sono annullati';de = 'Rabatte werden entfernt'"));
		EndIf;
		
	EndIf;
	
	If Object.AssignmentMethod = PredefinedValue("Enum.DiscountValueType.Amount") Then  
		Object.AssignmentArea = PredefinedValue("Enum.DiscountApplyingArea.AtRow");
	EndIf;
	
	UpdateAutoNaming(True);
	
EndProcedure

// Procedure - event  handler OnChange item ProvisionArea.
//
&AtClient
Procedure AssignmentAreaOnChange(Item)
	
	VisibleManagementAtServer();
	UpdateAutoNaming(True);
	
EndProcedure

&AtClient
Procedure ConditionsOfAssignmentAfterDeleteRow(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - event handler OnChange item Name.
//
&AtClient
Procedure DescriptionOnChange(Item)
	
	DescriptionChangedByUser = True;
	
EndProcedure

// Procedure - event handler OnChange item DiscountMarkupValue.
//
&AtClient
Procedure DiscountMarkupValueOnChange(Item)
	
	If Object.AssignmentMethod = AssignmentMethodPercent Then
		If Object.DiscountMarkupValue > 100 Then
			MessageText = NStr("en = 'Discount percent should not exceed 100%'; ru = 'Процент скидки должен быть не более 100%';pl = 'Procent rabatu nie powinien przekraczać 100%';es_ES = 'Por ciento de descuento no tiene que exceder un 100%';es_CO = 'Por ciento de descuento no tiene que exceder un 100%';tr = 'İndirim yüzdesi %100''ü geçmemelidir';it = 'La percentuale di sconto non può superare il 100%';de = 'Rabattprozentsatz sollte 100% nicht überschreiten'");
			CommonClientServer.MessageToUser(MessageText, 
																,
																"DiscountMarkupValue",
																"Object");
			Object.DiscountMarkupValue = 0;
		EndIf;
	EndIf;
	UpdateAutoNaming(True);

EndProcedure

// Procedure - event handler OnChange Parent item.
//
&AtClient
Procedure ParentOnChange(Item)
	
	ParentOnChangeAtServer();
	
EndProcedure

// Server part of procedure ParentOnChange.
//
&AtServer
Procedure ParentOnChangeAtServer()
	
	SharedUsageCurOption = GetSharedUsageCurrentOption(Object.Parent);
	
	Items.AdditionalOrderingAttribute.Visible = (Object.AdditionalOrderingAttribute > 0 OR SharedUsageCurOption = PredefinedValue("Enum.DiscountsApplyingRules.Exclusion") 
													OR SharedUsageCurOption = PredefinedValue("Enum.DiscountsApplyingRules.Multiplication"));
	
	Items.DecorationParentSharedUsageVariant.Title = String(SharedUsageCurOption);
	Items.DecorationParentSharedUsageVariant.Visible = Not Object.Parent.IsEmpty();
	
EndProcedure

// Procedure - event handler OnChange item Purpose.
//
&AtClient
Procedure PurposeOnChange(Item)
	
	RecipientsVisibleSetupAtServer();
	UpdateAutoNaming(True);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

#EndRegion

#Region ProceduresSpreadsheetPartEventsHandlers

// Procedure - events handler OnChange item form AssignmentCondition.
//
&AtClient
Procedure AssignmentConditionsOnChange(Item)
	
	UpdateAutoNaming(True);
	
EndProcedure

// Procedure - events handler OnChange form SP TimeByWeekDays.
//
&AtClient
Procedure TimeByDaysOfWeekOnChange(Item)
	
	UpdateAutoNaming(True);
	
EndProcedure

// Procedure - event handler OnChange form SP DiscountRecipientsCounterparties.
//
&AtClient
Procedure DiscountRecipientsOnChange(Item)
	
	UpdateAutoNaming(True);
	
EndProcedure

// Procedure - events handler OnChange form SP DiscountRecipientsWarehouses.
//
&AtClient
Procedure DiscountRecipientsWarehousesOnChange(Item)
	
	UpdateAutoNaming(True);
	
EndProcedure

// Procedure - event handler OnChange form SP ProductsGroupsPriceGroups.
//
&AtClient
Procedure ProductsGroupsPriceGroupsOnChange(Item)
	
	UpdateAutoNaming(True);
	
EndProcedure

&AtClient
Procedure ProductsGroupsPriceGroupsAfterDeleteRow(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - events handler OnStartEdit form SP TimeByWeekDays.
//
&AtClient
Procedure TimeByDaysOfWeekOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		Item.CurrentData.Selected = True;
		Item.CurrentData.BeginTime = '00010101000000';
		Item.CurrentData.EndTime = '00010101235959';
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// The procedure controls visible of form items depending on the automatic discount assignment.
//
&AtServer
Procedure RecipientsVisibleSetupAtServer()

	If Object.Purpose = PurposeRetail Then
		Items.GroupCounterparties.Visible = False;
		Items.WarehouseGroups.Visible = True;
		Items.SegmentGroup.Visible = False;
		Items.GroupsWarehousesAndCounterparties.PagesRepresentation = FormPagesRepresentation.None;
	ElsIf Object.Purpose = PurposeWholesale Then
		Items.GroupCounterparties.Visible = True;
		Items.WarehouseGroups.Visible = False;
		Items.SegmentGroup.Visible = True;
		Items.GroupsWarehousesAndCounterparties.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	Else
		Items.GroupCounterparties.Visible = True;
		Items.WarehouseGroups.Visible = True;
		Items.SegmentGroup.Visible = True;
		Items.GroupsWarehousesAndCounterparties.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	EndIf;

EndProcedure

#EndRegion