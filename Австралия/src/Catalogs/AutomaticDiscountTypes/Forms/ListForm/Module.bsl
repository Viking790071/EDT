#Region ServiceProceduresAndFunctions

#Region ListSorting

// The procedure checks the configured sorting by the
// attribute "AdditionalSortingAttribute" and suggests to set this sorting.
//
&AtClient
Procedure ValidateListFilter()
	
	SortingSetupParameters = New Structure;
	SortingSetupParameters.Insert("ListAttribute", List);
	SortingSetupParameters.Insert("ListItem", Items.List);
	
	If Not SortInListIsSetCorrectly(List) Then
		QuestionText = NStr("en = 'It is recommended
		                    |to sort the list by the field ""Order"". Configure the necessary sorting?'; 
		                    |ru = 'Сортировку списка рекомендуется установить по полю ""Порядок"".
		                    |Настроить необходимую сортировку?';
		                    |pl = 'Zalecane jest
		                    |uporządkowanie listy według pola ""Zamówienie"". Skonfigurować niezbędne sortowanie?';
		                    |es_ES = 'Se recomienda
		                    |clasificar la lista por el campo ""Pedido"". ¿Configurar la clasificación necesaria?';
		                    |es_CO = 'Se recomienda
		                    |clasificar la lista por el campo ""Pedido"". ¿Configurar la clasificación necesaria?';
		                    |tr = 'Listeyi ""Sipariş"" alanına göre sıralamanız 
		                    |önerilir. Gerekli sıralama yapılandırılsın mı?';
		                    |it = 'Si consiglia
		                    | di ordinare l''elenco in base al campo ""Ordine"". Configurare l''ordinamento necessario?';
		                    |de = 'Es empfiehlt sich,
		                    |die Liste nach dem Feld ""Auftrag"" zu sortieren. Die erforderliche Sortierung konfigurieren?'");
		NotifyDescription = New NotifyDescription("CheckListBeforeOperationResponseForSortingReceived", ThisObject, SortingSetupParameters);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Customize'; ru = 'Настроить';pl = 'Dostosuj';es_ES = 'Personalizar';es_CO = 'Personalizar';tr = 'Özelleştir';it = 'Personalizzare';de = 'Anpassung'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not configure'; ru = 'Не настраивать';pl = 'Nie konfigurować';es_ES = 'No configurar';es_CO = 'No configurar';tr = 'Yapılandırma';it = 'Non configurare';de = 'Nicht konfigurieren'"));
		ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.Yes);
		Return;
	EndIf;
	
EndProcedure

// The function checks that the list is sorted by the attribute AdditionalOrderingAttribute.
//
&AtClient
Function SortInListIsSetCorrectly(List)
	
	UserOrderSettings = Undefined;
	For Each Item In List.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	If UserOrderSettings = Undefined Then
		Return True;
	EndIf;
	
	OrderItems = UserOrderSettings.Items;
	
	// Find the first used order item
	Item = Undefined;
	For Each OrderingItem In OrderItems Do
		If OrderingItem.Use Then
			Item = OrderingItem;
			Break;
		EndIf;
	EndDo;
	
	If Item = Undefined Then
		// No sorting is set
		Return False;
	EndIf;
	
	If TypeOf(Item) = Type("DataCompositionOrderItem") Then
		If Item.OrderType = DataCompositionSortDirection.Asc Then
			AttributeField = New DataCompositionField("AdditionalOrderingAttribute");
			If Item.Field = AttributeField Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// The procedure processes user response to the question about the sorting by the attribute AdditionalOrderingAttribute.
//
&AtClient
Procedure CheckListBeforeOperationResponseForSortingReceived(ResponseResult, AdditionalParameters) Export
	
	If ResponseResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetListSortingByFieldOrder();
	
EndProcedure

// The procedure sets the order by the field AdditionalOrderingAttribute.
//
&AtClient
Procedure SetListSortingByFieldOrder()
	
	ListAttribute = List;
	
	UserOrderSettings = Undefined;
	For Each Item In ListAttribute.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	CommonClientServer.Validate(UserOrderSettings <> Undefined, NStr("en = 'Custom order setup setting was not found.'; ru = 'Пользовательская настройка порядка не найдена.';pl = 'Nie znaleziono niestandardowego ustawienia konfiguracji zamówienia.';es_ES = 'Configuración del ajuste del pedido personalizado no se ha encontrado.';es_CO = 'Configuración del ajuste del pedido personalizado no se ha encontrado.';tr = 'Özel sipariş ayarı bulunamadı.';it = 'L''ordine personalizzato non è stato trovato.';de = 'Die Einstellung für die benutzerdefinierte Auftragseinrichtung wurde nicht gefunden.'"));
	
	UserOrderSettings.Items.Clear();
	Item = UserOrderSettings.Items.Add(Type("DataCompositionOrderItem"));
	Item.Use = True;
	Item.Field = New DataCompositionField("AdditionalOrderingAttribute");
	Item.OrderType = DataCompositionSortDirection.Asc;
	
EndProcedure

#EndRegion

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	//AdditionalOrderingAttribute
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("List.ColorYellow");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ColorYellow = StyleColors.AutomaticDiscountsYellow;
	
	ItemAppearance.Appearance.SetParameterValue("BackColor", ColorYellow);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("AdditionalOrderingAttribute");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	Items.List.ReadOnly = Not AllowedEditDocumentPrices;
	
	SharedUsageVariantOfDiscounts = Constants.DefaultDiscountsApplyingRule.Get();
	If SharedUsageVariantOfDiscounts.IsEmpty() Then
		SharedUsageVariantOfDiscounts = Enums.DiscountsApplyingRules.Addition;
		Constants.DefaultDiscountsApplyingRule.Set(SharedUsageVariantOfDiscounts);
	EndIf;
	
	//Conditional appearance
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsApplyingRules.Exclusion")
		OR SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsApplyingRules.Multiplication") Then
		SetListSortingByFieldOrder();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - CreateJointApplicationGroup command handler of the form.
//
&AtClient
Procedure CreateFolderSharedUse(Presentation)
	
	GroupFormParameters = New Structure("IsFolder", True);
	OpenForm("Catalog.AutomaticDiscountTypes.FolderForm", GroupFormParameters,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item DiscountsSharedUsageOption.
//
&AtClient
Procedure SharedUsageVariantOfDiscountsOnChange(Item)
	
	DiscountsJointApplicationOptionOnChangeAtServer(SharedUsageVariantOfDiscounts);
	If SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsApplyingRules.Exclusion")
		OR SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsApplyingRules.Multiplication") Then
		ValidateListFilter();
	EndIf;
	Items.List.Refresh();
	
EndProcedure

// Procedure - event handler OnChange item DiscountsJointApplicationOption (server part).
//
&AtServerNoContext
Procedure DiscountsJointApplicationOptionOnChangeAtServer(SharedUsageVariantOfDiscounts)
	
	Constants.DefaultDiscountsApplyingRule.Set(SharedUsageVariantOfDiscounts);
	
EndProcedure

#EndRegion
