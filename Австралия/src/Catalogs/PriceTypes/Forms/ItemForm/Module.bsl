#Region FormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.PriceCurrency) Then
		
		Object.PriceCurrency = DriveReUse.GetFunctionalCurrency();
		
	EndIf;
	
	SetItemsVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	ReadOnly = Not AllowedEditDocumentPrices;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(Object.Ref) Then
		
		Query = New Query(
		"SELECT
		|	BusinessUnits.Ref AS StructuralUnit
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON BusinessUnits.Company = Companies.Ref
		|WHERE
		|	BusinessUnits.RetailPriceKind = &RetailPriceKind
		|	AND Companies.PresentationCurrency <> &PriceCurrency"
		);
		
		Query.SetParameter("RetailPriceKind", CurrentObject.Ref);
		Query.SetParameter("PriceCurrency", CurrentObject.PriceCurrency);
		QueryExecutionResult = Query.Execute();
		
		If Not QueryExecutionResult.IsEmpty() Then
			
			MessageText = NStr("en = 'Current price type is used in retail business units whose presentation currency differs from the currency of this price.'; ru = 'Текущий тип цен используется в розничных структурных единицах, валюта представления отчетности которых отличается от валюты текущей цены.';pl = 'Bieżący rodzaj bieżącej ceny jest używany w detalicznych jednostkach biznesowych, waluta prezentacji których różni się od waluty ceny bieżącej.';es_ES = 'El tipo de precio corriente se utiliza en unidades de negocio minoristas cuya moneda de presentación difiere de la moneda de este precio.';es_CO = 'El tipo de precio corriente se utiliza en unidades de negocio minoristas cuya moneda de presentación difiere de la moneda de este precio.';tr = 'Mevcut fiyat türü, finansal tablo para birimi bu fiyatın para biriminden farklı olan perakende departmanlarda kullanılıyor.';it = 'Il tipo di prezzo corrente è utilizzato nelle unità di vendita al dettaglio, la cui valuta di presentazione differisce dalla valuta del prezzo corrente.';de = 'Der aktuelle Preistyp ist bei den Abteilungen von Einzelhandel verwendet, deren Währung für die Berichtserstattung sich von der Währung des aktuellen Preises unterscheidet.'");
			CommonClientServer.MessageToUser(MessageText, , "Object.PriceCurrency", , Cancel);
			
		EndIf;
		
	EndIf;

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange of the PriceCalculationMethod input field.
//
Procedure PriceCalculationMethodOnChange(Item)
	
	SetItemsVisible();
	
EndProcedure

&AtClient
// Procedure event handler OnChange of the "BasePriceKind"
//
// It makes sence only for dynamic price types, as currency and the value of the parameter are taken from the base PriceIncludesVAT
//
Procedure PricesBaseKindOnChange(Item)
	
	If Object.Ref = Object.PricesBaseKind Then
		
		Object.PricesBaseKind = Undefined;
		CommonClientServer.MessageToUser(NStr("en = 'You can not select the same price type as you are editing. Select another.'; ru = 'Невозможно выбрать тот же тип цен, который в данный момент редактируется. Выберите другой тип цен.';pl = 'Nie możesz wybrać tego samego rodzaju ceny, którą edytujesz. Wybierz inny.';es_ES = 'Usted no puede seleccionar el mismo tipo de precios que está editando. Seleccionar otro.';es_CO = 'Usted no puede seleccionar el mismo tipo de precios que está editando. Seleccionar otro.';tr = 'Düzenlediğiniz gibi aynı fiyat türünü seçemezsiniz. Başka bir fiyat türünü seçin.';it = 'Non è possibile selezionare lo stesso tipo di prezzo che si sta modificando. Sceglierne un altro.';de = 'Sie können nicht denselben Preistyp auswählen, den Sie bearbeiten. Wählen Sie einen anderen aus.'"));
		
		Return;
		
	EndIf;
	
	BasePriceData = GetBasePriceData(Object.PricesBaseKind);
	
	Object.PriceCurrency	= BasePriceData.PriceCurrency;
	Object.PriceIncludesVAT	= BasePriceData.PriceIncludesVAT;
	
EndProcedure

&AtClient
Procedure FormulaOpening(Item, StandardProcessing)
	
	OpenFormulaBuilder();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ChangeFormula(Command)
	
	OpenFormulaBuilder();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
// Procedure controls the visible of items.
//
Procedure SetItemsVisible()
	
	If Object.PriceCalculationMethod = Enums.PriceCalculationMethods.CalculatedDynamic Then
		
		Items.PricesBaseKind.Visible = True;
		Items.PricesBaseKind.AutoChoiceIncomplete = True;
		Items.PricesBaseKind.AutoMarkIncomplete = True;
		Items.Percent.Visible = True;
		Items.GroupFormula.Visible = False;
		Items.Company.AutoChoiceIncomplete = True;
		Items.Company.AutoMarkIncomplete = True;
		
		Items.PriceCalculationMethod.ToolTip = NStr("en = 'Prices are calculated every time you use this price type.'; ru = 'Расчет цен производится каждый раз, когда вы используете данный тип цен.';pl = 'Ceny są obliczane za każdym razem, gdy używasz tego rodzaju ceny.';es_ES = 'Los precios se calculan cada vez que utilice este tipo de precio.';es_CO = 'Los precios se calculan cada vez que utilice este tipo de precio.';tr = 'Fiyatlar, bu fiyat türünü her kullanışınızda hesaplanır.';it = 'I prezzi sono calcolati tutte le volte in cui viene utilizzato questa tipologia di prezzo.';de = 'Die Preise werden bei jeder Verwendung dieses Preistyps berechnet.'");
		
		Object.CalculatesDynamically = True;
		
		Object.PriceCurrency 		= ?(ValueIsFilled(Object.PricesBaseKind), Object.PricesBaseKind.PriceCurrency, Catalogs.Currencies.EmptyRef());
		Object.PriceIncludesVAT 	= ?(ValueIsFilled(Object.PricesBaseKind), Object.PricesBaseKind.PriceIncludesVAT, False);
		
	ElsIf Object.PriceCalculationMethod = Enums.PriceCalculationMethods.CalculatedStatic Then
		
		Items.PricesBaseKind.Visible = True;
		Items.PricesBaseKind.AutoChoiceIncomplete = True;
		Items.PricesBaseKind.AutoMarkIncomplete = True;
		Items.Percent.Visible = True;
		Items.GroupFormula.Visible = False;
		Items.Company.AutoChoiceIncomplete = False;
		Items.Company.AutoMarkIncomplete = False;
		
		Items.PriceCalculationMethod.ToolTip = NStr("en = 'For this pricing method, 
			|go to Sales > Tools > Prices setup and set prices.'; 
			|ru = 'Для этого способа расчета цены 
			|перейдите в меню Продажи > Сервис > Настройка цен и установите цены.';
			|pl = 'Dla tej metody ustalania cen, 
			|przejdź do Sprzedaż > Narzędzia > Ustalanie cen i ustaw ceny.';
			|es_ES = 'Para este método de fijación de precios, 
			|ir a Ventas > Herramientas > Configuración de precios y fijar los precios.';
			|es_CO = 'Para este método de fijación de precios, 
			|ir a Ventas > Herramientas > Configuración de precios y fijar los precios.';
			|tr = 'Bu fiyatlandırma yöntemi için 
			|Satış > Araçlar > Fiyat ayarlaması bölümüne gidip fiyatları ayarlayın.';
			|it = 'Per questo metodo di determinazione del prezzo, 
			|andare in Vendite > Strumenti > Configurazione prezzo e impostare i prezzi.';
			|de = 'Für diese Preismethode, 
			|gehen Sie zu Verkauf> Service > Preisgestaltung und geben Sie Preise ein.'");
		
		Object.CalculatesDynamically = False;
		
	ElsIf Object.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
	
		Items.PricesBaseKind.Visible = False;
		Items.PricesBaseKind.AutoChoiceIncomplete = False;
		Items.PricesBaseKind.AutoMarkIncomplete = False;
		Items.Percent.Visible = False;
		Items.GroupFormula.Visible = True;
		Items.Company.AutoChoiceIncomplete = False;
		Items.Company.AutoMarkIncomplete = False;
		
		Items.PriceCalculationMethod.ToolTip = NStr("en = 'Prices are not stored.
			|Prices in the documents are recalculated automatically according to the formula.'; 
			|ru = 'Цены не сохраняются.
			|Цены в документах автоматически пересчитываются по формуле.';
			|pl = 'Ceny nie są zapisywane.
			|Ceny są przeliczane automatyczne zgodnie z formułą.';
			|es_ES = 'Los precios no se guardan. 
			|Los precios en los documentos se recalculan automáticamente según la fórmula.';
			|es_CO = 'Los precios no se guardan. 
			|Los precios en los documentos se recalculan automáticamente según la fórmula.';
			|tr = 'Fiyatlar depolanmaz.
			| Belgelerdeki fiyatlar formüle göre otomatik olarak yeniden hesaplanır.';
			|it = 'I prezzi non sono stati archiviati.
			|I prezzi nel documento sono ricalcolati automaticamente secondo la formula.';
			|de = 'Die Preise werden nicht gespeichert.
			|Die Preise in den Dokumenten werden automatisch nach der Formel neu berechnet.'");
		
		Object.CalculatesDynamically = True;
		
	Else
		
		Items.PricesBaseKind.Visible = False;
		Items.PricesBaseKind.AutoChoiceIncomplete = False;
		Items.PricesBaseKind.AutoMarkIncomplete = False;
		Items.Percent.Visible = False;
		Items.GroupFormula.Visible = False;
		Items.Company.AutoChoiceIncomplete = False;
		Items.Company.AutoMarkIncomplete = False;
		
		Object.PricesBaseKind = Undefined;
		Object.Percent = 0;
		
		Items.PriceCalculationMethod.ToolTip =  NStr("en = 'Prices are specified manually.'; ru = 'Цены указаны вручную.';pl = 'Ceny są określane ręcznie.';es_ES = 'Los precios se especifican manualmente.';es_CO = 'Los precios se especifican manualmente.';tr = 'Fiyatlar manuel olarak belirlenir.';it = 'I prezzi sono specificati manualmente.';de = 'Die Preise werden manuell festgelegt.'");
		
		Object.CalculatesDynamically = False;
		
	EndIf;
	
	Items.PriceCurrency.Enabled = (Object.PriceCalculationMethod <> Enums.PriceCalculationMethods.CalculatedDynamic);
	Items.PriceIncludesVAT.Enabled = (Object.PriceCalculationMethod <> Enums.PriceCalculationMethods.CalculatedDynamic);
	
EndProcedure

&AtServerNoContext
// Procedure receives detailed data
// from the basic price, used only if
// the current item has dynamic kind
//
Function GetBasePriceData(PricesBaseKind)
	
	Return New Structure("PriceCurrency, PriceIncludesVAT", 
			?(ValueIsFilled(PricesBaseKind), PricesBaseKind.PriceCurrency, Catalogs.Currencies.EmptyRef()), 
			?(ValueIsFilled(PricesBaseKind), PricesBaseKind.PriceIncludesVAT, False));
	
EndFunction

&AtClient
// The procedure opens the formula constructor
//
Procedure OpenFormulaBuilder()
	
	StandardProcessing = False;
	
	FormulaParameters = New Structure("Formula, Company", Object.Formula, Object.Company);
	NotifyDescription = New NotifyDescription("FormulaBuilderEnd", ThisObject);
	
	OpenForm("Catalog.PriceTypes.Form.FormulaBuilder",
		FormulaParameters,
		Items.Formula,
		,
		,
		,
		NotifyDescription,
		FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

&AtClient
Procedure FormulaBuilderEnd(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") AND Result.Property("ClosedOK") AND Result.ClosedOK Then
		
		Result.Property("Formula", Object.Formula);
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure
// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion