
#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	MetadataObject = Object.Ref.Metadata();
	
	If Parameters.Property("AdditionalParameters")
		And Parameters.AdditionalParameters.Property("Parent") Then
		
		Object.Parent = Parameters.AdditionalParameters.Parent;
		
	EndIf;
	
	
	// Bundles
	FOUseProductBundles = GetFunctionalOption("UseProductBundles");
	FillUsingInBundles();
	// End Bundles
	
	ChartPricesPeriodicity = DataAnalysisTimeIntervalUnitType.Day;
	
	IsUseProductCrossReferences = Constants.UseProductCrossReferences.Get();
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(
		Object.Description,
		Object.DescriptionFull);
		
	FillListTypes();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Not ValueIsFilled(Parameters.CopyingValue) Then
			Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(,);
			Object.VATRate			= Policy.DefaultVATRate;
			Object.ConversionRate	= 1;
		EndIf;
		
		If Not IsBlankString(Parameters.FillingText) AND GenerateDescriptionFullAutomatically Then
			Object.DescriptionFull = Parameters.FillingText;
		EndIf;
		
		InheritUseBatchesCharacteristcsSerialNumbersFlags();
		SetVisibleAndEnabled(True);
		
	Else
		
		SetVisibleAndEnabled();
		
		ChartPricesPeriod = Undefined;
		ChartSalesPeriod = Undefined;
		GetFormData();
		
	EndIf;
	
	SetAdditionalUOMs();
	
	InsertImagesFromProducts = False;
	
	NotifyPickup = False;
	ItemModified = False;
	
	FillPicturesViewer();
	
	// FO Use the subsystems Production, Work.
	SetVisibleByFOUseProductionJobsSubsystem();
		
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
	AdditionalParameters.Insert("DeferredInitialization", True);
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	DriveServer.ChangeQueryTextForCurrentLanguage(ThisObject.AdditionalUOMs.QueryText);
	
	WarrantyMonthsText	= NStr("en = 'months'; ru = 'месяцы';pl = 'miesięcy';es_ES = 'meses';es_CO = 'meses';tr = 'aylar';it = 'mesi';de = 'Monate'");
	ShelfLifeMonthsText	= NStr("en = 'months'; ru = 'месяцы';pl = 'miesięcy';es_ES = 'meses';es_CO = 'meses';tr = 'aylar';it = 'mesi';de = 'Monate'");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetChartsVisible();
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Bundles
	FillUsingInBundles();
	// End Bundle
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		ChangeOpenAdditionalAttributesButton();
	EndIf;
	// End StandardSubsystems.Properties
	
	If EventName = "PriceChanged"
		AND Parameter.Find(Object.Ref) <> Undefined Then
		
		AttachIdleHandler("NotificationProcessingPriceChangedAtClient", 0.5, True);
		
	ElsIf InsertImagesFromProducts
		AND EventName = "Write_File" Then
		
		RefreshPicturesViewer(Source);
		
		If Parameter.Property("IsNew") And Parameter.IsNew
			And Not ValueIsFilled(Object.PictureFile) Then
			
			If TypeOf(Source) = Type("Array") Then
				PictureToCheck = Source[0];
			Else
				PictureToCheck = Source;
			EndIf;
			
			Rows = Pictures.FindRows(New Structure("PictureRef", PictureToCheck));
			If Rows.Count() <> 0 Then
				SetMainImageAtServer(PictureToCheck);
			EndIf;
			
		EndIf;
		
	ElsIf EventName = "InputInMultipleLanguages"
		And GenerateDescriptionFullAutomatically Then
		
		Object.DescriptionFull = Object.Description;
		
	ElsIf (EventName = "SupplierProductSetAsDefault" 
		Or EventName = "SupplierProductClearByDefault")
		And Parameter = Object.Ref Then
		
		ThisObject.Read();
		
		SetVisibleAndEnabledCrossReferences();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	If Modified Then
		ItemModified = True;
	EndIf;
	
	// Duplicates blocking
	If ValueIsFilled(DuplicateRulesIndexTableAddress) And ValueIsFilled(Object.Ref) Then
		CurrentObject.AdditionalProperties.Insert("DuplicateRulesIndexTableAddress", DuplicateRulesIndexTableAddress);
	EndIf;
	
	If ValueIsFilled(ModificationTableAddress) Then
		CurrentObject.AdditionalProperties.Insert("ModificationTableAddress", ModificationTableAddress);
	EndIf;
	// End Duplicates blocking
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
// Procedure-handler  of the AfterWriteOnServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
	If ItemModified Then
		NotifyPickup = True;
		ItemModified = False;
	EndIf;
	
	SetVisibleAndEnabled();
	
	SetAdditionalUOMs();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Bundles
	If ItIsBundleWithPerComponentPricing(Object) Then
		Items.PricesOverview.Visible = True;
		AttachIdleHandler("NotificationProcessingPriceChangedAtClient", 0.5, True);
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
// BeforeRecord event handler procedure.
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// Bundles
	If Object.IsBundle And Not IsInventoryItem() And Not IsWork() Then
		Object.IsBundle = False;
	EndIf;
	If Object.IsBundle And (Bundles.Count() > 0) Then
		Object.IsBundle = False;
	EndIf;
	// End Bundles
	
	// Duplicates blocking
	If Not WriteParameters.Property("NotToCheckDuplicates") Then
		
		DuplicateCheckingParameters = DriveClient.GetDuplicateCheckingParameters(ThisObject);
		DuplicatesTableStructure = DuplicatesTableStructureAtServer(DuplicateCheckingParameters);
		
		If ValueIsFilled(DuplicatesTableStructure.DuplicatesTableAddress) Then
			
			Cancel = True;
			
			FormParameters = New Structure;
			FormParameters.Insert("Ref", DuplicateCheckingParameters.Ref);
			FormParameters.Insert("DuplicatesTableStructure", DuplicatesTableStructure);
			
			NotificationDescriptionOnCloseDuplicateChecking = New NotifyDescription("OnCloseDuplicateChecking", ThisObject);
			
			OpenForm("DataProcessor.DuplicateChecking.Form.DuplicateChecking",
				FormParameters,
				ThisObject,
				True,
				,
				,
				NotificationDescriptionOnCloseDuplicateChecking);
				
		EndIf;
		
	EndIf;
	// End Duplicates blocking
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
	If Cancel Then
		Return;
	EndIf;
	
	If NotifyPickup 
		AND TypeOf(FormOwner) = Type("ClientApplicationForm")
		AND FormOwner.FormName = "CommonForm.PickForm" Then
		Notify("RefreshPickup", True);
	// CWP
	ElsIf NotifyPickup 
		AND TypeOf(FormOwner) = Type("ClientApplicationForm")
		AND Find(FormOwner.FormName, "DocumentForm_CWP") > 0 Then
		Notify("ProductsIsAddedFromCWP", Object.Ref);
	EndIf;
	// End CWP
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseBatchesOnChange(Item)
	
	SetUseBatchesWarningOnEdit();
	
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	// StandardSubsystems.Properties
	If Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		PropertiesRunDeferredInitialization();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		ChangeOpenAdditionalAttributesButton();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Description field.
//
Procedure DescriptionOnChange(Item)

	If GenerateDescriptionFullAutomatically Then
		
		Object.DescriptionFull = Object.Description;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ProductsType field.
//
Procedure ProductsTypeOnChange(Item)
	
	// Bundles
	If Object.IsBundle And Not IsInventoryItem() Then
		Object.IsBundle = False;
	EndIf;
	// End Bundles
	
	SetVisibleAndEnabled(True);
	
EndProcedure

&AtClient
// Procedure - Open event handler of the Warehouse field.
//
Procedure WarehouseOpening(Item, StandardProcessing)
	
	If Items.Warehouse.ListChoiceMode
		AND Not ValueIsFilled(Object.Warehouse) Then
		
		StandardProcessing = False;
		
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - SelectionStart event handler of the Specification field.
//
Procedure BillsOfMaterialStartChoice(Item,  ChoiceData, StandardProcessing)
		
	If Not ValueIsFilled(Object.Ref) Then
		
		StandardProcessing = False;
		Message = New UserMessage();
		Message.Text = NStr("en = 'Catalog item is not recorded yet'; ru = 'Элемент справочника еще не записан.';pl = 'Pozycja katalogu nie jest jeszcze zarejestrowana';es_ES = 'Artículo del catálogo aún no se ha registrado';es_CO = 'Artículo del catálogo aún no se ha registrado';tr = 'Dizin öğesi heniz kaydedilmedi.';it = 'L''elemento della anagrafica non è ancora registrato';de = 'Katalog Artikel ist noch nicht aufgenommen'");
		Message.Message();
		
	EndIf;

	StandardProcessing = False;
	
	ProductOwner = Object.Ref;
	
	ParametersFormBOM = New Structure("DateChoice, Filter", 
		CurrentDate(),
		New Structure("Owner, Status", 
			ProductOwner, 
			PredefinedValue("Enum.BOMStatuses.Active")));
		
	ChoiceHandler = New NotifyDescription("BillsOfMaterialStartChoiceEnd", ThisObject);
	
	OpenForm("Catalog.BillsOfMaterials.ChoiceForm", ParametersFormBOM, ThisObject, , , , ChoiceHandler);
	
EndProcedure

&AtClient
Procedure BillsOfMaterialStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	Object.Specification = ResultValue;
	
EndProcedure

&AtClient
Procedure VendorOnChange(Item)
	
	Object.ProductCrossReference = PredefinedValue("Catalog.SuppliersProducts.EmptyRef");
	
	SetVisibleAndEnabledCrossReferences();
	
EndProcedure

&AtClient
Procedure DecorationNextPictureClick(Item)
	MovePicture(1);
EndProcedure

&AtClient
Procedure DecorationPreviousPictureClick(Item)
	MovePicture(-1);
EndProcedure

&AtClient
// Procedure - Click event handler of the ImageURL address.
//
Procedure PictureURLClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	If Items.PictureURL.ReadOnly Then
		Return;
	EndIf;
	
	LockFormDataForEdit();
	AddImageAtClient();
	
EndProcedure

&AtClient
Procedure Attachable_PictureURLClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If CurrentPicture >= 0 Then
		SeeAttachedFile();
	Else
		LockFormDataForEdit();
		AddImageAtClient();
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the DescriptionFull attribute
//
&AtClient
Procedure DescriptionFullOnChange(Item)
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(Object.Description, Object.DescriptionFull);
	
EndProcedure

&AtClient
Procedure ProductsCategoryOnChange(Item)
	ProductsCategoryOnChangeAtServer();
EndProcedure

&AtClient
Procedure GuaranteePeriodOnChange(Item)
	
	Object.WriteOutTheGuaranteeCard = (Object.GuaranteePeriod > 0);
	SetWriteOutTheGuaranteeCardAvailability();
	
EndProcedure

&AtClient
Procedure AdditionalUOMsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
	If Object.Ref.IsEmpty() Then
		
		QuestionText = NStr("en = 'To add a UOM, save the object. Do you want to save the object?'; ru = 'Для добавления единицы измерения необходимо сохранить объект. Сохранить?';pl = 'Aby dodać jednostkę miary, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para seleccionar una unidad de medida, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para seleccionar una unidad de medida, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Ölçü birimi eklemek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per aggiungere una Unità di Misura, salvare l''oggetto. Salvare l''oggetto?';de = 'Um eine Maßeinheit hinzuzufügen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("AddUOMFragment", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		AddUOMEnd();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MeasurementUnitOnChange(Item)
	
	If Object.ReportUOM <> Object.MeasurementUnit Then
		Object.ReportUOM = Object.MeasurementUnit;
		Object.ConversionRate = 1;
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure ReportUOMOnChange(Item)
	
	If Object.ReportUOM = Object.MeasurementUnit Then
		Object.ConversionRate = 1;
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#Region Bundles

&AtClient
Procedure IsBundleOnChange(Item)
	
	If Not CanChangeIsBundleAttribute() Then
		Return;
	EndIf;
	
	If Object.IsBundle Then
		Object.UseSerialNumbers = False;
		Object.UseBatches = False;
		If Not ValueIsFilled(Object.BundlePricingStrategy) Then
			Object.BundlePricingStrategy = PredefinedValue("Enum.ProductBundlePricingStrategy.PerComponentPricing");
		EndIf;
		If Not ValueIsFilled(Object.BundleDisplayInPrintForms) Then
			Object.BundleDisplayInPrintForms = PredefinedValue("Enum.ProductBundleDisplay.BundleAndComponents");
		EndIf;
	Else
		Object.BundlePricingStrategy = PredefinedValue("Enum.ProductBundlePricingStrategy.EmptyRef");
		Object.BundleDisplayInPrintForms = PredefinedValue("Enum.ProductBundleDisplay.EmptyRef");
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure BundleDisplayInPrintFormsOnChange(Item)
	
	If Object.BundleDisplayInPrintForms = PredefinedValue("Enum.ProductBundleDisplay.Bundle")
		And Not CheckDifferentVATInComponents(Object.Ref) Then
		CommonClientServer.MessageToUser(
				NStr("en = 'Components of bundle have different VAT rates and the print method for this bundle is specified as Bundle.
							|It means that it will be displayed on print forms as one line, which can have only one VAT rate.
							|You can either select components with the same VAT rate, or change the print method of this bundle.'; 
							|ru = 'Компоненты набора имеют разные ставки НДС, а метод печати для этого бандла определен как Набор.
							|Это означает, что он будет отображаться в печатных формах в одну строку, которая может иметь только одну ставки НДС.
							|Вы можете либо выбрать компоненты с одинаковой ставкой НДС, либо изменить способ печати для этого набора.';
							|pl = 'Komponenty zestawu mają różne stawki VAT i formularz wydruku dla tego zestawu jest określony jako Zestaw.
							|To znaczy, że on będzie wyświetlany w formularzach wydruku jako jeden wiersz, który może mieć tylko jedną stawkę VAT.
							|Możesz wybrać komponenty z taką samą stawką VAT lub zmienić sposób wydruku tego zestawu.';
							|es_ES = 'Los componentes del paquete tienen tipos de IVA diferentes y el método de impresión para este paquete se especifica como Paquete.
							|Significa que se visualizará en los formularios de impresión como una línea, que sólo puede tener un tipo de IVA.
							|Puede seleccionar componentes con el mismo tipo de IVA o modificar el método de impresión de este paquete.';
							|es_CO = 'Los componentes del paquete tienen tipos de IVA diferentes y el método de impresión para este paquete se especifica como Paquete.
							|Significa que se visualizará en los formularios de impresión como una línea, que sólo puede tener un tipo de IVA.
							|Puede seleccionar componentes con el mismo tipo de IVA o modificar el método de impresión de este paquete.';
							|tr = 'Paket bileşenleri farklı KDV oranlarına sahiptir ve bu paket için yazdırma yöntemi Paket olarak belirtilir. 
							|Bu, baskı formlarında tek bir KDV oranına sahip olabilecek bir satır olarak görüntüleneceği anlamına gelir. 
							|Aynı KDV oranına sahip bileşenleri seçebilir veya bu paketin yazdırma yöntemini değiştirebilirsiniz.';
							|it = 'I componenti del kit di prodotti hanno diverse aliquote IVA e la modalità di stampe per questo kit di prodotti è specificata come Kit di prodotti.
							|Significa che sarà mostrato nei moduli di stampa come una unica linea che può avere solo un''aliquota IVA.
							|Potete o selezionare componenti con la stessa aliquota IVA o modificare la modalità di stampa di questo kit di prodotti.';
							|de = 'Materialbestand der Artikelgruppe hat unterschiedliche USt.-Sätze und die Druckmethode für dieser Artikelgruppe wird als Artikelgruppe angegeben.
							|Das bedeutet, dass es auf Druckformularen als eine Zeile angezeigt wird, die nur einen USt.-Satz haben kann.
							|Sie können entweder Materialbestand mit dem gleichen USt.-Satz auswählen oder die Druckmethode dieser Artikelgruppe ändern.'"),,
				"Object.BundleDisplayInPrintForms");
	EndIf;
	
EndProcedure

&AtClient
Procedure BundlesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	SelectedItem = Bundles.FindByID(SelectedRow);
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Key", SelectedItem.Value);
	OpenForm("Catalog.Products.ObjectForm", ParametersStructure, ThisObject);
	
EndProcedure

#EndRegion

#Region AnalyticalData

&AtClient
Procedure NotificationProcessingPriceChangedAtClient()
	
	NotificationProcessingPriceChanged();
	
EndProcedure

&AtClient
Procedure ChartPricesPeriodTitleClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = ChartPricesPeriod;
	Description = New NotifyDescription("ChartPricesPeriodTitleClickEnd", ThisObject);
	Dialog.Show(Description);
	
EndProcedure

&AtClient
Procedure ChartPricesPeriodTitleClickEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ChartPricesPeriodTitleClickEndAtServer(Result);
	
EndProcedure

&AtServer
Procedure ChartPricesPeriodTitleClickEndAtServer(Result)
	
	ChartPricesPeriod = Result;
	CorrectPeriodicity = CorrectPeriodicity(Result.StartDate, Result.EndDate);
	ChartPricesSetPeriodicity(CorrectPeriodicity);
	
	ChartPricesSetPeriodTitle();
	GetFormData("ChartPrices");
	
EndProcedure

&AtClient
Procedure ChartSalesPeriodTitleClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = ChartSalesPeriod;
	Description = New NotifyDescription("ChartSalesPeriodTitleClickEnd", ThisObject);
	Dialog.Show(Description);

EndProcedure

&AtClient
Procedure ChartSalesPeriodTitleClickEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ChartSalesPeriodTitleClickEndAtServer(Result);
	
EndProcedure

&AtServer
Procedure ChartSalesPeriodTitleClickEndAtServer(Result)
	
	ChartSalesPeriod = Result;
	CorrectPeriodicity = CorrectPeriodicity(Result.StartDate, Result.EndDate);
	ChartSalesSetPeriodicity(CorrectPeriodicity);
	
	ChartSalesSetPeriodTitle();
	GetFormData("ChartSales");
	
EndProcedure

#EndRegion

&AtClient
Procedure OpenCrossReference(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If Item.ReadOnly Then
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		QuestionText = NStr("en = 'To add a cross-reference, save the object. Do you want to save the object?'; ru = 'Для добавления номенклатуры поставщика необходимо сохранить объект. Сохранить?';pl = 'Aby dodać powiązane informacje, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para añadir una referencia cruzada, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para añadir una referencia cruzada, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Çapraz referans eklemek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per aggiungere un riferimento incrociato, salvare l''oggetto. Salvare l''oggetto?';de = 'Um eine Herstellerartikelnummer hinzuzufügen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		ShowQueryBox(New NotifyDescription("OpenCrossReferenceFragment", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		OpenCrossReferenceEnd();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCrossReferenceFragment(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No 
		Or Not Write() Then
		Return;
	EndIf;
	
	OpenCrossReferenceEnd();
	
EndProcedure

&AtClient
Procedure OpenCrossReferenceEnd()
	
	StructureFilter = New Structure("Products", Object.Ref);
	
	If ValueIsFilled(Object.Vendor) Then
		StructureFilter.Insert("Owner", Object.Vendor);
	EndIf;
	
	ParameterStructure = New Structure("Filter, UseFilledSKU", StructureFilter, True);
	
	NotifySelectedCrossReference = New NotifyDescription("SelectedCrossReference", ThisObject);
	
	OpenForm("Catalog.SuppliersProducts.ChoiceForm", ParameterStructure, , , , , NotifySelectedCrossReference);
	
EndProcedure

&AtClient
Procedure SelectedCrossReference(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		StructureCrossReference = GetStructureCrossReference(Result);
		
		If StructureCrossReference.IsFillCharacteristic Then
			
			MessageText = NStr("en = 'Cannot set cross-reference as default. 
				|Select cross-reference without variant and repeat action'; 
				|ru = 'Невозможно сделать данную номенклатуру поставщика ссылкой по умолчанию. 
				|Выберите номенклатуру поставщика, у которой нет вариантов, и повторите действие';
				|pl = 'Nie można ustawić powiązanych informacji jako domyślnych. 
				|Zaznacz powiązane informacje bez wariantu i powtórz działanie';
				|es_ES = 'No se puede establecer la referencia cruzada por defecto.
				|Seleccione la referencia cruzada sin variante y repita la acción';
				|es_CO = 'No se puede establecer la referencia cruzada por defecto.
				|Seleccione la referencia cruzada sin variante y repita la acción';
				|tr = 'Çapraz referans varsayılan olarak ayarlanamıyor.
				|Varyantsız çapraz referans seçip işlemi tekrarlayın';
				|it = 'Impossibile impostare il riferimento incrociato come predefinito. 
				|Selezionare riferimento incrociato senza variante e ripetere l''azione';
				|de = 'Die Herstellerartikelnummer kann nicht als Standard festgelegt werden. 
				|Wählen Sie eine Herstellerartikelnummer ohne Variante aus und wiederholen die Aktion'");
			CommonClientServer.MessageToUser(MessageText);
			Return;
			
		EndIf;
		
		Object.ProductCrossReference	= Result;
		Object.Vendor					= StructureCrossReference.Owner;
		
		ThisObject.Modified = True;
		
		SetVisibleAndEnabled();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure VisibleToExternalUsersOnChange(Item)
	
	Items.AccessGroup.Visible = Object.VisibleToExternalUsers;
	If Not Object.VisibleToExternalUsers Then
		Object.AccessGroup = PredefinedValue("Catalog.ProductAccessGroupsForExternalUsers.EmptyRef");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CopyWithRelatedData(Command)
	
	OpenForm("Catalog.Products.Form.CloneForm", New Structure("Product", Object.Ref));
	
EndProcedure

// Procedure - AddImage command handler
//
&AtClient
Procedure AddImage(Command)
	
	AddImageAtClient();
	
EndProcedure

// Procedure - ClearImage command handler
//
&AtClient
Procedure ClearImage(Command)
	
	AttachedFile = Pictures[CurrentPicture].PictureRef;
	
	If ValueIsFilled(AttachedFile) Then
		
		DeleteAttachedFile(AttachedFile);
		
		NotifyChanged(AttachedFile);
		Notify("Write_File", New Structure, AttachedFile);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetMainImage(Command)
	
	If CurrentPicture >= 0 Then
		SetMainImageAtServer(Pictures[CurrentPicture].PictureRef);
	EndIf;
	
EndProcedure

// Procedure - ClearImage command handler
//
&AtClient
Procedure SeeImage(Command)
	
	SeeAttachedFile();
	
EndProcedure

&AtClient
Procedure OpenAdditionalAttributes(Command)
	PropertyManagerClient.ExecuteCommand(ThisObject);
EndProcedure

// Bundles
&AtClient
Procedure ComponentsOfTheBundle(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select bundle components, save the object. Do you want to save the object?'; ru = 'Для выбора компонентов набора необходимо сохранить объект. Сохранить?';pl = 'Aby wybrać komponenty zestawu, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para seleccionar los componentes del paquete, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para seleccionar los componentes del paquete, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Set bileşenlerini seçmek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per selezionare i componenti del kit di prodotti, salvare l''oggetto. Salvare l''oggetto?';de = 'Um die Artikelgruppe auszuwählen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("ComponentsOfTheBundleEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		ComponentsOfTheBundleFragment();
		
	EndIf;
	
EndProcedure

#Region InternalProceduresAndFunctions

&AtServer
Procedure InheritUseBatchesCharacteristcsSerialNumbersFlags()
	
	If Parameters.Key.IsEmpty() And ValueIsFilled(Object.ProductsCategory) Then
		ProductCategoryData = Common.ObjectAttributesValues(Object.ProductsCategory,
			"UseBatches, UseCharacteristics, UseSerialNumbers");
		FillPropertyValues(Object, ProductCategoryData);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProductsCategoryOnChangeAtServer()
	
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject,, False);
	
	InheritUseBatchesCharacteristcsSerialNumbersFlags();
	
	SetVisibleAndEnabled(True);
	
EndProcedure

&AtServer
Procedure ChangeOpenAdditionalAttributesButton()
	
	If Items.AdditionalAttributesPage.ChildItems.Count() > 1 Then
		Items.OpenAdditionalAttributes.Title	= NStr("en = 'Set up additional attributes'; ru = 'Установить дополнительные реквизиты';pl = 'Ustaw dodatkowe atrybuty';es_ES = 'Configurar atributos adicionales';es_CO = 'Configurar atributos adicionales';tr = 'Ek öznitelikleri ayarla';it = 'Imposta attributi aggiuntivi';de = 'Zusätzliche Attribute einrichten'");
		Items.OpenAdditionalAttributes.Visible	= Users.RolesAvailable("AddEditBasicReferenceData");
	Else
		Items.OpenAdditionalAttributes.Title = NStr("en = 'There are no additional attributes for this product. Click here to create attributes'; ru = 'Для данной номенклатуры нет доп. реквизитов. Нажмите сюда, чтобы создать реквизиты';pl = 'Dla tego produktu nie ma dodatkowych atrybutów. Kliknij tutaj, aby utworzyć atrybuty';es_ES = 'No hay atributos adicionales para este producto. Hacer clic aquí para crear atributos';es_CO = 'No hay atributos adicionales para este producto. Hacer clic aquí para crear atributos';tr = 'Bu ürün için ek öznitelik yok. Öznitelik oluşturmak için buraya tıklayın';it = 'Non ci sono attributi aggiuntivi per questo articolo. Premete qui per creare attributi';de = 'Für dieses Produkt gibt es keine zusätzlichen Attribute. Klicken Sie hier, um Attribute zu erstellen'");
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	AfterProcessingHandler = New NotifyDescription(
		"Attachable_AfterAllowObjectAttributesEditingProcessing", ThisObject);
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject, AfterProcessingHandler);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_AfterAllowObjectAttributesEditingProcessing(Result, AdditionalParameters) Export
	
	SetWriteOutTheGuaranteeCardAvailability();
	SetUseBatchesWarningOnEdit();
	
EndProcedure

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

&AtServer
Procedure PropertiesRunDeferredInitialization()
	PropertyManager.FillAdditionalAttributesINForm(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region AnalyticalData

&AtClient
Procedure HideCharts(Command)
	
	HideCharts = Not HideCharts;
	SetChartsVisible();
	
EndProcedure

&AtClient
Procedure ChartPricesByDays(Command)
	ChartPricesPeriodChanging(DataAnalysisTimeIntervalUnitType.Day);
EndProcedure

&AtClient
Procedure ChartPricesByMonths(Command)
	ChartPricesPeriodChanging(DataAnalysisTimeIntervalUnitType.Month);
EndProcedure

&AtClient
Procedure ChartPricesByQuarters(Command)
	ChartPricesPeriodChanging(DataAnalysisTimeIntervalUnitType.Quarter);
EndProcedure

&AtClient
Procedure ChartPricesByWeeks(Command)
	ChartPricesPeriodChanging(DataAnalysisTimeIntervalUnitType.Week);
EndProcedure

&AtClient
Procedure ChartPricesByYears(Command)
	ChartPricesPeriodChanging(DataAnalysisTimeIntervalUnitType.Year);
EndProcedure

&AtClient
Procedure ChartSalesByDays(Command)
	ChartSalesPeriodChanging(DataAnalysisTimeIntervalUnitType.Day);
EndProcedure

&AtClient
Procedure ChartSalesByWeeks(Command)
	ChartSalesPeriodChanging(DataAnalysisTimeIntervalUnitType.Week);
EndProcedure

&AtClient
Procedure ChartSalesByMonths(Command)
	ChartSalesPeriodChanging(DataAnalysisTimeIntervalUnitType.Month);
EndProcedure

&AtClient
Procedure ChartSalesByQuarters(Command)
	ChartSalesPeriodChanging(DataAnalysisTimeIntervalUnitType.Quarter);
EndProcedure

&AtClient
Procedure ChartSalesByYears(Command)
	ChartSalesPeriodChanging(DataAnalysisTimeIntervalUnitType.Year);
EndProcedure

&AtClient
Procedure ChartSalesByQuantity(Command)
	
	Items.ChartSalesQuantity.Visible = True;
	Items.ChartSales.Visible = False;
	Items.ChartSalesByAmount.Visible = True;
	Items.ChartSalesByQuantity.Visible = False;
	
EndProcedure

&AtClient
Procedure ChartSalesByAmount(Command)
	
	Items.ChartSalesQuantity.Visible = False;
	Items.ChartSales.Visible = True;
	Items.ChartSalesByAmount.Visible = False;
	Items.ChartSalesByQuantity.Visible = True;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region ActualPrices

&AtServer
Procedure ActualPriceDeleteItems()
	
	ItemsToDelete = New Array;
	
	For Each Item In Items.ActualPrices.ChildItems Do
		If Item <> Items.DecorationPricesNotFilled Then
			ItemsToDelete.Add(Item);
		EndIf;
	EndDo;
	
	For Each Item In ItemsToDelete Do
		Items.Delete(Item);
	EndDo;
	
EndProcedure

#EndRegion

#Region AnalyticalData

&AtServer
Function QueryDescriptionActualPrices(Query, Areas)
	
	Result = New Structure;
	
	If FOUseProductBundles And ItIsBundleWithPerComponentPricing(Object) Then
		
		Result.Insert("QueryText",
			"SELECT ALLOWED
			|	SUM(CAST(PricesSliceLast.Price * BundlesComponents.Quantity / CASE
			|				WHEN PricesSliceLast.MeasurementUnit REFS Catalog.UOM
			|					THEN PricesSliceLast.MeasurementUnit.Factor
			|				ELSE 1
			|			END AS NUMBER(15, 2))) AS Price,
			|	PricesSliceLast.PriceKind AS PriceKind,
			|	MAX(PricesSliceLast.Period) AS Period
			|FROM
			|	BundlesComponents AS BundlesComponents
			|		LEFT JOIN InformationRegister.Prices.SliceLast(
			|				&CurrentDate,
			|				(Products, Characteristic) IN
			|					(SELECT
			|						BundlesComponents.Products,
			|						BundlesComponents.Characteristic
			|					FROM
			|						BundlesComponents)) AS PricesSliceLast
			|		ON BundlesComponents.Products = PricesSliceLast.Products
			|			AND BundlesComponents.Characteristic = PricesSliceLast.Characteristic
			|WHERE
			|	NOT PricesSliceLast.PriceKind IS NULL
			|	AND BundlesComponents.BundleCharacteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
			|
			|GROUP BY
			|	PricesSliceLast.PriceKind
			|
			|ORDER BY
			|	Price DESC");
		
	Else
		
		Result.Insert("QueryText",
			"SELECT ALLOWED
			|	PricesSliceLast.PriceKind AS PriceKind,
			|	PricesSliceLast.Period AS Period,
			|	PricesSliceLast.Price AS Price
			|FROM
			|	InformationRegister.Prices.SliceLast(
			|			&CurrentDate,
			|			Products = &Products
			|				AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS PricesSliceLast
			|
			|ORDER BY
			|	Price DESC");
		
	EndIf;
	
	Result.Insert("BatchNumber", 1);
	Result.Insert("Show", True);
	
	Return Result;
	
EndFunction

&AtServer
Function QueryDescriptionChartPrices(Query, Areas)
	
	Result = New Structure;
	PeriodIsFilled = ValueIsFilled(ChartPricesPeriod);
	
	QuerySeparator = DriveClientServer.GetQueryDelimeter();
	
	BatchNumber = 2;
	
	If FOUseProductBundles And ItIsBundleWithPerComponentPricing(Object) Then
		
		TempTablesManager = New TempTablesManager;
		QueryBundles = New Query;
		QueryBundles.TempTablesManager = TempTablesManager;
		
		// Bundle components
		QueryBundles.SetParameter("Products", Object.Ref);
		QueryBundles.Text =
		"SELECT
		|	BundlesComponents.Products AS Products,
		|	BundlesComponents.Characteristic AS Characteristic,
		|	SUM(BundlesComponents.Quantity * CASE
		|			WHEN BundlesComponents.MeasurementUnit REFS Catalog.UOM
		|				THEN BundlesComponents.MeasurementUnit.Factor
		|			ELSE 1
		|		END) AS Quantity
		|INTO BundlesComponents
		|FROM
		|	InformationRegister.BundlesComponents AS BundlesComponents
		|WHERE
		|	BundlesComponents.BundleProduct = &Products
		|	AND BundlesComponents.BundleCharacteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
		|
		|GROUP BY
		|	BundlesComponents.Products,
		|	BundlesComponents.Characteristic";
		QueryBundles.Execute();
		
		// Default period
		If Not PeriodIsFilled Then
			ChartPricesSetPeriodicity(DataAnalysisTimeIntervalUnitType.Day);
			QueryBundles.Text =
			"SELECT ALLOWED DISTINCT TOP 5
			|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%) AS Period
			|INTO PeriodsTable
			|FROM
			|	InformationRegister.Prices AS Prices
			|WHERE
			|	(Prices.Products, Prices.Characteristic) IN
			|			(SELECT
			|				BundlesComponents.Products,
			|				BundlesComponents.Characteristic
			|			FROM
			|				BundlesComponents AS BundlesComponents)
			|
			|GROUP BY
			|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%)
			|
			|ORDER BY
			|	Period DESC
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	MAX(ENDOFPERIOD(PeriodsTable.Period, %PeriodDetalization%)) AS EndOfPeriod,
			|	MIN(BEGINOFPERIOD(PeriodsTable.Period, %PeriodDetalization%)) AS BegOfPeriod
			|FROM
			|	PeriodsTable AS PeriodsTable";
			QueryBundles.Text = StrReplace(QueryBundles.Text, "%PeriodDetalization%", PeriodicityString(ChartPricesPeriodicity));
			Selection = QueryBundles.Execute().Select();
			
			BegOfQueryPeriod = Undefined;
			EndOfQueryPeriod = Undefined;
			If Selection.Next() Then
				BegOfQueryPeriod = Selection.BegOfPeriod;
				EndOfQueryPeriod = Selection.EndOfPeriod;
			EndIf;
		Else
			BegOfQueryPeriod = ?(ValueIsFilled(ChartPricesPeriod.StartDate), ChartPricesPeriod.StartDate, Undefined);
			EndOfQueryPeriod = ?(ValueIsFilled(ChartPricesPeriod.EndDate), ChartPricesPeriod.EndDate, Undefined);
		EndIf;
		
		If ValueIsFilled(BegOfQueryPeriod) Then
			SlicePeriod = BegOfDay(BegOfQueryPeriod) - 1;
			QueryBundles.SetParameter("SlicePeriod", SlicePeriod);
			QueryBundles.Text =
			"SELECT
			|	BundlesComponents.Products AS Products,
			|	BundlesComponents.Characteristic AS Characteristic,
			|	BundlesComponents.Quantity AS Quantity
			|FROM
			|	BundlesComponents AS BundlesComponents
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	BundlesComponents.Products AS Products,
			|	BundlesComponents.Characteristic AS Characteristic,
			|	PricesSliceLast.Price / CASE
			|		WHEN PricesSliceLast.MeasurementUnit REFS Catalog.UOM
			|			THEN PricesSliceLast.MeasurementUnit.Factor
			|		ELSE 1
			|	END AS Price,
			|	PricesSliceLast.PriceKind AS PriceKind
			|FROM
			|	BundlesComponents AS BundlesComponents
			|		LEFT JOIN InformationRegister.Prices.SliceLast(
			|				&SlicePeriod,
			|				(Products, Characteristic) IN
			|					(SELECT
			|						BundlesComponents.Products,
			|						BundlesComponents.Characteristic
			|					FROM
			|						BundlesComponents AS BundlesComponents)) AS PricesSliceLast
			|		ON BundlesComponents.Products = PricesSliceLast.Products
			|			AND BundlesComponents.Characteristic = PricesSliceLast.Characteristic
			|TOTALS BY
			|	PriceKind";
		Else
			QueryBundles.Text =
			"SELECT
			|	BundlesComponents.Products AS Products,
			|	BundlesComponents.Characteristic AS Characteristic,
			|	BundlesComponents.Quantity AS Quantity
			|FROM
			|	BundlesComponents AS BundlesComponents
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	UNDEFINED AS PriceKind
			|WHERE
			|	FALSE
			|TOTALS BY
			|	PriceKind";
		EndIf;
		QueryBundles.Text = QueryBundles.Text + QuerySeparator;
		QueryBundles.SetParameter("StartDate", ?(ValueIsFilled(BegOfQueryPeriod), BegOfQueryPeriod, '00010101'));
		QueryBundles.SetParameter("EndDate", ?(ValueIsFilled(EndOfQueryPeriod), EndOfQueryPeriod, '39991231'));
		QueryBundles.Text = QueryBundles.Text +
		"SELECT ALLOWED
		|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%) AS Period,
		|	AVG(Prices.Price / CASE
		|			WHEN Prices.MeasurementUnit REFS Catalog.UOM
		|				THEN Prices.MeasurementUnit.Factor
		|			ELSE 1
		|		END) AS Price,
		|	Prices.PriceKind AS PriceKind,
		|	Prices.Products AS Products,
		|	Prices.Characteristic AS Characteristic
		|FROM
		|	InformationRegister.Prices AS Prices
		|WHERE
		|	(Prices.Products, Prices.Characteristic) IN
		|			(SELECT
		|				BundlesComponents.Products,
		|				BundlesComponents.Characteristic
		|			FROM
		|				BundlesComponents AS BundlesComponents)
		|	AND Prices.Period >= &StartDate
		|	AND Prices.Period <= &EndDate
		|
		|GROUP BY
		|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%),
		|	Prices.PriceKind,
		|	Prices.Products,
		|	Prices.Characteristic
		|
		|ORDER BY
		|	Period
		|TOTALS BY
		|	Period,
		|	PriceKind";
		QueryBundles.Text = StrReplace(QueryBundles.Text, "%PeriodDetalization%", PeriodicityString(ChartPricesPeriodicity));
		QueryResult = QueryBundles.ExecuteBatch();
		SelectionComponents = QueryResult.Get(0).Select();
		SelectionFirstPricesPriceKind = QueryResult.Get(1).Select(QueryResultIteration.ByGroups);
		SelectionPricesPeriod = QueryResult.Get(2).Select(QueryResultIteration.ByGroups);
		PricesTable = New ValueTable;
		PricesTable.Columns.Add("Period", New TypeDescription("Date", New DateQualifiers(DateFractions.Date)));
		PricesTable.Columns.Add("Price", New TypeDescription("Number", New NumberQualifiers(15, 2)));
		PricesTable.Columns.Add("PriceKind", New TypeDescription("CatalogRef.PriceTypes"));
		PreviousPrices = New Map;
		
		If SelectionFirstPricesPriceKind.Count() > 0 Then
			While SelectionFirstPricesPriceKind.Next() Do
				PricesByPriceKind = PreviousPrices.Get(SelectionFirstPricesPriceKind.PriceKind);
				If PricesByPriceKind = Undefined Then
					FillPricesMap(PreviousPrices, SelectionFirstPricesPriceKind.PriceKind, SelectionComponents);
					PricesByPriceKind = PreviousPrices.Get(SelectionFirstPricesPriceKind.PriceKind);
				EndIf;
				SelectionFirstPricesProducts = SelectionFirstPricesPriceKind.Select();
				While SelectionFirstPricesProducts.Next() Do
					PricesByPriceKind.Get(SelectionFirstPricesProducts.Products).Insert(SelectionFirstPricesProducts.Characteristic, SelectionFirstPricesProducts.Price);
				EndDo;
			EndDo;
		EndIf;
		
		If ValueIsFilled(BegOfQueryPeriod) Then
			For Each PriceDescription In PreviousPrices Do
				PriceKind = PriceDescription.Key;
				If ValueIsFilled(PriceKind) Then
					PriceByPriceKind = PriceDescription.Value;
					SelectionComponents.Reset();
					Price = 0;
					While SelectionComponents.Next() Do
						Price = Price + SelectionComponents.Quantity
								* PricesByPriceKind.Get(SelectionComponents.Products).Get(SelectionComponents.Characteristic);
					EndDo;
					PriceRow = PricesTable.Add();
					PriceRow.Period = BegOfInterval(BegOfQueryPeriod, ChartPricesPeriodicity) - 1;
					PriceRow.PriceKind = PriceKind;
					PriceRow.Price = Price;
				EndIf;
			EndDo;
		EndIf;
		
		While SelectionPricesPeriod.Next() Do
			SelectionPricesPriceKind = SelectionPricesPeriod.Select(QueryResultIteration.ByGroups);
			While SelectionPricesPriceKind.Next() Do
				PricesByPriceKind = PreviousPrices.Get(SelectionPricesPriceKind.PriceKind);
				If PricesByPriceKind = Undefined Then
					FillPricesMap(PreviousPrices, SelectionPricesPriceKind.PriceKind, SelectionComponents);
					PricesByPriceKind = PreviousPrices.Get(SelectionPricesPriceKind.PriceKind);
				EndIf;
				SelectionPricesProducts = SelectionPricesPriceKind.Select();
				While SelectionPricesProducts.Next() Do
					PricesByPriceKind.Get(SelectionPricesProducts.Products).Insert(SelectionPricesProducts.Characteristic, SelectionPricesProducts.Price);
				EndDo;
				SelectionComponents.Reset();
				Price = 0;
				While SelectionComponents.Next() Do
					Price = Price + SelectionComponents.Quantity
							* PricesByPriceKind.Get(SelectionComponents.Products).Get(SelectionComponents.Characteristic);
				EndDo;
				PriceRow = PricesTable.Add();
				PriceRow.Period = SelectionPricesPeriod.Period;
				PriceRow.PriceKind = SelectionPricesPriceKind.PriceKind;
				PriceRow.Price = Price;
			EndDo;
		EndDo;
		
		Query.SetParameter("PricesTable", PricesTable);
		
		Result.Insert("QueryText",
			"SELECT
			|	PricesTable.Period AS Period,
			|	PricesTable.Price AS Price,
			|	PricesTable.PriceKind AS PriceKind
			|INTO PricesTable
			|FROM
			|	&PricesTable AS PricesTable
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	PricesTable.Period AS Period,
			|	PricesTable.Price AS Price,
			|	PricesTable.PriceKind AS PriceKind
			|FROM
			|	PricesTable AS PricesTable
			|
			|ORDER BY
			|	Period
			|TOTALS BY
			|	Period");
		
		BatchNumber = 2;
		
	ElsIf ValueIsFilled(ChartPricesPeriod) Or ValueIsFilled(Areas) Then
		
		Result.Insert("QueryText",
			"SELECT ALLOWED
			|	Prices.PriceKind AS PriceKind,
			|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%) AS Period,
			|	AVG(Prices.Price) AS Price
			|FROM
			|	InformationRegister.Prices AS Prices
			|WHERE
			|	Prices.Products = &Products
			|	AND Prices.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
			|	AND &ChartSalesPeriodStartDate
			|	AND &ChartSalesPeriodEndDate
			|
			|GROUP BY
			|	Prices.PriceKind,
			|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%)
			|
			|ORDER BY
			|	Period
			|TOTALS BY
			|	Period");
		
		BatchNumber = 1;
		
	Else
		
		ChartPricesSetPeriodicity(DataAnalysisTimeIntervalUnitType.Day);
		Result.Insert("QueryText",
			"SELECT ALLOWED TOP 5
			|	Prices.PriceKind AS PriceKind,
			|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%) AS Period,
			|	AVG(Prices.Price) AS Price
			|INTO Prices
			|FROM
			|	InformationRegister.Prices AS Prices
			|WHERE
			|	Prices.Products = &Products
			|	AND Prices.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
			|
			|GROUP BY
			|	Prices.PriceKind,
			|	BEGINOFPERIOD(Prices.Period, %PeriodDetalization%)
			|
			|ORDER BY
			|	Period DESC
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	Prices.Period AS Period,
			|	Prices.Price AS Price,
			|	Prices.PriceKind AS PriceKind
			|FROM
			|	Prices AS Prices
			|
			|ORDER BY
			|	Period
			|TOTALS BY
			|	Period");
		
	EndIf;
	
	Result.Insert("BatchNumber", BatchNumber);
	Result.Insert("Show", True);
	
	Return Result;
	
EndFunction

&AtServer
Function QueryDescriptionChartSales(Query, Areas)
	
	Result = New Structure;
	Show = True;
	QueryText = "";
	BatchNumber = 1;
	
	If FOUseProductBundles And Object.IsBundle Then
		
		If ValueIsFilled(ChartSalesPeriod) Then
			
			QueryText = "SELECT ALLOWED
			|	%Period% AS Period,
			|	SUM(SalesTurnovers.QuantityTurnover) AS Quantity,
			|	SUM(SalesTurnovers.AmountTurnover) AS Revenue,
			|	SUM(SalesTurnovers.CostTurnover) AS COGS
			|FROM
			|	AccumulationRegister.Sales.Turnovers(&ChartSalesStartDate, &ChartSalesEndDate, Auto, BundleProduct = &Products) AS SalesTurnovers
			|
			|GROUP BY
			|	%Period%
			|
			|ORDER BY
			|	Period";
			
		Else
			
			QueryFirstLastSale = New Query;
			QueryFirstLastSale.Text = 
			"SELECT ALLOWED TOP 1
			|	Sales.Period AS Period
			|FROM
			|	AccumulationRegister.Sales AS Sales
			|WHERE
			|	Sales.BundleProduct = &Products
			|
			|UNION ALL
			|
			|SELECT TOP 1
			|	Sales.Period
			|FROM
			|	AccumulationRegister.Sales AS Sales
			|WHERE
			|	Sales.BundleProduct = &Products
			|
			|ORDER BY
			|	Period DESC";
			
			QueryFirstLastSale.SetParameter("Products", Object.Ref);
			QueryResult = QueryFirstLastSale.ExecuteBatch();
			
			StartDate = Undefined;
			EndDate = Undefined;
			
			SelectionFirtSale = QueryResult[0].Select();
			While SelectionFirtSale.Next() Do
				StartDate = SelectionFirtSale.Period;
			EndDo;
			
			SelectionEndSale = QueryResult[0].Select();
			While SelectionEndSale.Next() Do
				EndDate = SelectionEndSale.Period;
			EndDo;
			
			If StartDate <> Undefined And EndDate <> Undefined Then
				
				ChartSalesPeriod.StartDate = StartDate;
				ChartSalesPeriod.EndDate = EndDate;
				
				CorrectPeriodicity = CorrectPeriodicity(StartDate, EndDate);
				ChartSalesSetPeriodicity(CorrectPeriodicity);
				
				Query.SetParameter("SalesStartDate", BegOfInterval(StartDate, CorrectPeriodicity));
				Query.SetParameter("SalesEndDate", EndOfInterval(EndDate, CorrectPeriodicity));
				
				QueryText = "SELECT ALLOWED
				|	%Period% AS Period,
				|	SUM(SalesTurnovers.QuantityTurnover) AS Quantity,
				|	SUM(SalesTurnovers.AmountTurnover) AS Revenue,
				|	SUM(SalesTurnovers.CostTurnover) AS COGS
				|FROM
				|	AccumulationRegister.Sales.Turnovers(&SalesStartDate, &SalesEndDate, Auto, BundleProduct = &Products) AS SalesTurnovers
				|
				|GROUP BY
				|	%Period%
				|
				|ORDER BY
				|	Period";
				
			Else
				
				Show = False;
				
			EndIf;
			
		EndIf;
		
	Else
		
		If ValueIsFilled(ChartSalesPeriod) Then
			
			QueryText = "SELECT ALLOWED
			|	%Period% AS Period,
			|	SUM(SalesTurnovers.QuantityTurnover) AS Quantity,
			|	SUM(SalesTurnovers.AmountTurnover) AS Revenue,
			|	SUM(SalesTurnovers.CostTurnover) AS COGS
			|FROM
			|	AccumulationRegister.Sales.Turnovers(&ChartSalesStartDate, &ChartSalesEndDate, Auto, Products = &Products) AS SalesTurnovers
			|
			|GROUP BY
			|	%Period%
			|
			|ORDER BY
			|	Period";
			
		Else
			
			QueryFirstLastSale = New Query;
			QueryFirstLastSale.Text = 
			"SELECT ALLOWED TOP 1
			|	Sales.Period AS Period
			|FROM
			|	AccumulationRegister.Sales AS Sales
			|WHERE
			|	Sales.Products = &Products
			|
			|ORDER BY
			|	Period
			|;
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	Sales.Period
			|FROM
			|	AccumulationRegister.Sales AS Sales
			|WHERE
			|	Sales.Products = &Products
			|
			|ORDER BY
			|	Period DESC";
			
			QueryFirstLastSale.SetParameter("Products", Object.Ref);
			QueryResult = QueryFirstLastSale.ExecuteBatch();
			
			StartDate = Undefined;
			EndDate = Undefined;
			
			SelectionFirtSale = QueryResult[0].Select();
			While SelectionFirtSale.Next() Do
				StartDate = SelectionFirtSale.Period;
			EndDo;
			
			SelectionEndSale = QueryResult[1].Select();
			While SelectionEndSale.Next() Do
				EndDate = SelectionEndSale.Period;
			EndDo;
			
			If StartDate <> Undefined And EndDate <> Undefined Then
				
				ChartSalesPeriod.StartDate = StartDate;
				ChartSalesPeriod.EndDate = EndDate;
				
				CorrectPeriodicity = CorrectPeriodicity(StartDate, EndDate);
				ChartSalesSetPeriodicity(CorrectPeriodicity);
				
				Query.SetParameter("SalesStartDate", BegOfInterval(StartDate, CorrectPeriodicity));
				Query.SetParameter("SalesEndDate", EndOfInterval(EndDate, CorrectPeriodicity));
				
				QueryText = "SELECT ALLOWED
				|	%Period% AS Period,
				|	SUM(SalesTurnovers.QuantityTurnover) AS Quantity,
				|	SUM(SalesTurnovers.AmountTurnover) AS Revenue,
				|	SUM(SalesTurnovers.CostTurnover) AS COGS
				|FROM
				|	AccumulationRegister.Sales.Turnovers(&SalesStartDate, &SalesEndDate, Auto, Products = &Products) AS SalesTurnovers
				|
				|GROUP BY
				|	%Period%
				|
				|ORDER BY
				|	Period";
				
			Else
				
				Show = False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Result.Insert("QueryText", QueryText);
	Result.Insert("BatchNumber", BatchNumber);
	Result.Insert("Show", Show);
	
	Return Result;
	
EndFunction

&AtServer
Function QueryDescriptionOnHand(Query, Areas)
	
	Result = New Structure;
	
	Result.Insert("QueryText",
		"SELECT ALLOWED
		|	ReservedProductsBalance.StructuralUnit AS StructuralUnit,
		|	ReservedProductsBalance.Characteristic AS Characteristic,
		|	ReservedProductsBalance.Batch AS Batch,
		|	0 AS OnHand,
		|	ReservedProductsBalance.QuantityBalance AS Reserved
		|INTO TT_OnHandAndReserved
		|FROM
		|	AccumulationRegister.ReservedProducts.Balance(, Products = &Products) AS ReservedProductsBalance
		|
		|UNION ALL
		|
		|SELECT
		|	InventoryBalance.StructuralUnit,
		|	InventoryBalance.Characteristic,
		|	InventoryBalance.Batch,
		|	InventoryBalance.QuantityBalance,
		|	0
		|FROM
		|	AccumulationRegister.Inventory.Balance(
		|			,
		|			Products = &Products
		|				AND StructuralUnit <> VALUE(Catalog.BusinessUnits.DropShipping)) AS InventoryBalance
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_OnHandAndReserved.StructuralUnit AS StructuralUnit,
		|	TT_OnHandAndReserved.Characteristic AS Characteristic,
		|	TT_OnHandAndReserved.Batch AS Batch,
		|	SUM(TT_OnHandAndReserved.OnHand) AS OnHand,
		|	SUM(TT_OnHandAndReserved.Reserved) AS Reserved
		|FROM
		|	TT_OnHandAndReserved AS TT_OnHandAndReserved
		|
		|GROUP BY
		|	TT_OnHandAndReserved.StructuralUnit,
		|	TT_OnHandAndReserved.Characteristic,
		|	TT_OnHandAndReserved.Batch
		|
		|ORDER BY
		|	Characteristic,
		|	StructuralUnit
		|TOTALS BY
		|	Characteristic,
		|	StructuralUnit
		|AUTOORDER");
	
	Result.Insert("BatchNumber", 2);
	Result.Insert("Show", True);
	
	Return Result;

EndFunction

&AtServer
Procedure GetFormData(Areas = Undefined)
	
	Query = New Query;
	
	QueryActualPrices	= QueryDescriptionActualPrices(Query, Areas);
	QueryChartPrices	= QueryDescriptionChartPrices(Query, Areas);
	QueryChartSales		= QueryDescriptionChartSales(Query, Areas);
	QueryOnHand			= QueryDescriptionOnHand(Query, Areas);
	
	QuerySeparator = DriveClientServer.GetQueryDelimeter();
	
	If Areas = Undefined Then
		
		Areas = New Array;
		Areas.Add("ActualPrices");
		If Not HideCharts Then
			Areas.Add("ChartPrices");
			Areas.Add("ChartSales");
		EndIf;
		Areas.Add("OnHand");
		
	Else
		
		If TypeOf(Areas) = Type("String") Then
			AreasString = Areas;
			Areas = New Array;
			Areas.Add(AreasString);
		EndIf;
		
		For Each Area In Areas Do
			If Area = "ChartSales" And ItIsBundleWithPerComponentPricing(Object) Then
				Area = Undefined;
			EndIf;
		EndDo;
		
	EndIf;
	
	If Not AccessRight("Read", Metadata.InformationRegisters.Prices) Then
		
		ChartPricesIndex = Areas.Find("ChartPrices");
		ActualPricesIndex = Areas.Find("ActualPrices");
		
		If ChartPricesIndex <> Undefined Then
			Areas.Delete(ChartPricesIndex);
		EndIf;
		
		If ActualPricesIndex <> Undefined Then
			Areas.Delete(ActualPricesIndex);
		EndIf;
		
	EndIf;
	
	If Not AccessRight("Read", Metadata.AccumulationRegisters.Sales) Then
		
		ChartSalesIndex = Areas.Find("ChartSales");
		If ChartSalesIndex <> Undefined Then
			Areas.Delete(ChartSalesIndex);
		EndIf;
		
	EndIf;
	
	If Not AccessRight("Read", Metadata.AccumulationRegisters.Inventory)
		Or Not AccessRight("Read", Metadata.AccumulationRegisters.ReservedProducts) Then
		
		OnHandIndex = Areas.Find("OnHand");
		If OnHandIndex <> Undefined Then
			Areas.Delete(OnHandIndex);
		EndIf;
		
	EndIf;
	
	Query.Text = 
		"SELECT
		|	BundlesComponents.BundleCharacteristic AS BundleCharacteristic,
		|	BundlesComponents.Products AS Products,
		|	BundlesComponents.Characteristic AS Characteristic,
		|	SUM(BundlesComponents.Quantity * CASE
		|			WHEN BundlesComponents.MeasurementUnit REFS Catalog.UOM
		|				THEN BundlesComponents.MeasurementUnit.Factor
		|			ELSE 1
		|		END) AS Quantity
		|INTO BundlesComponents
		|FROM
		|	InformationRegister.BundlesComponents AS BundlesComponents
		|WHERE
		|	BundlesComponents.BundleProduct = &Products
		|
		|GROUP BY
		|	BundlesComponents.BundleCharacteristic,
		|	BundlesComponents.Products,
		|	BundlesComponents.Characteristic";
	
	TotalQueryStack = 1;
	
	For Each Area In Areas Do
		
		If Area = "ActualPrices" Then
			
			If ValueIsFilled(Query.Text) Then
				Query.Text = Query.Text + QuerySeparator;
			EndIf;
			
			Query.Text = Query.Text + QueryActualPrices.QueryText;
			Query.SetParameter("CurrentDate", CurrentSessionDate());
			TotalQueryStack = TotalQueryStack + QueryActualPrices.BatchNumber;
			QueryTextActualPricesBatchNumber = TotalQueryStack -1;
			
		ElsIf Area = "ChartPrices" Then
			
			If ValueIsFilled(Query.Text) Then
				Query.Text = Query.Text + QuerySeparator;
			EndIf;
			
			Query.Text = Query.Text + QueryChartPrices.QueryText;
			TotalQueryStack = TotalQueryStack + QueryChartPrices.BatchNumber;
			QueryTextChartPricesBatchNumber = TotalQueryStack -1;
			
			Query.Text = StrReplace(Query.Text, "%PeriodDetalization%", PeriodicityString(ChartPricesPeriodicity));
			If ValueIsFilled(ChartPricesPeriod.StartDate) Then
				Query.Text = StrReplace(Query.Text, "&ChartSalesPeriodStartDate", "Prices.Period >= &ChartSalesPeriodStartDate");
				Query.SetParameter("ChartSalesPeriodStartDate", ChartPricesPeriod.StartDate);
			Else
				Query.SetParameter("ChartSalesPeriodStartDate", True);
			EndIf;
			If ValueIsFilled(ChartPricesPeriod.EndDate) Then
				Query.Text = StrReplace(Query.Text, "&ChartSalesPeriodEndDate", "Prices.Period <= &ChartSalesPeriodEndDate");
				Query.SetParameter("ChartSalesPeriodEndDate", ChartPricesPeriod.EndDate);
			Else
				Query.SetParameter("ChartSalesPeriodEndDate", True);
			EndIf;
			
		ElsIf Area = "ChartSales" Then
			
			If Not QueryChartSales.Show Then
				Continue;
			EndIf;
			
			If ValueIsFilled(Query.Text) Then
				Query.Text = Query.Text + QuerySeparator;
			EndIf;
			
			Query.Text = Query.Text + QueryChartSales.QueryText;
			TotalQueryStack = TotalQueryStack + QueryChartSales.BatchNumber;
			QueryTextChartSalesBatchNumber = TotalQueryStack -1;
			
			If ChartSalesPeriodicity = DataAnalysisTimeIntervalUnitType.Day Then
				Query.Text = StrReplace(Query.Text, "%Period%", "SalesTurnovers.DayPeriod");
			ElsIf ChartSalesPeriodicity = DataAnalysisTimeIntervalUnitType.Week Then
				Query.Text = StrReplace(Query.Text, "%Period%", "SalesTurnovers.WeekPeriod");
			ElsIf ChartSalesPeriodicity = DataAnalysisTimeIntervalUnitType.Month Then
				Query.Text = StrReplace(Query.Text, "%Period%", "SalesTurnovers.MonthPeriod");
			ElsIf ChartSalesPeriodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
				Query.Text = StrReplace(Query.Text, "%Period%", "SalesTurnovers.QuarterPeriod");
			ElsIf ChartSalesPeriodicity = DataAnalysisTimeIntervalUnitType.Year Then
				Query.Text = StrReplace(Query.Text, "%Period%", "SalesTurnovers.YearPeriod");
			EndIf;
			
			Query.SetParameter("ChartSalesStartDate", ChartSalesPeriod.StartDate);
			Query.SetParameter("ChartSalesEndDate", ChartSalesPeriod.EndDate);
			
		ElsIf Area = "OnHand" Then
			
			If ValueIsFilled(Query.Text) Then
				Query.Text = Query.Text + QuerySeparator;
			EndIf;
			
			Query.Text = Query.Text + QueryOnHand.QueryText;
			TotalQueryStack = TotalQueryStack + QueryOnHand.BatchNumber;
			QueryTextOnHandBatchNumber = TotalQueryStack -1;
			
		EndIf;
		
	EndDo;
	
	ProductsUUID = "Products" + StrReplace(Object.Ref.UUID(), "-", "");
	Query.SetParameter(ProductsUUID, Object.Ref);
	Query.Text = StrReplace(Query.Text, "&Products", "&" + ProductsUUID);
	
	Result = Query.ExecuteBatch();
	
	If Areas.Find("ActualPrices") <> Undefined Then
		InitializeChartPrices();
		FillActualPrices(Result[QueryTextActualPricesBatchNumber]);
	EndIf;
	
	If Areas.Find("ChartPrices") <> Undefined Then
		FillChartPrices(Result[QueryTextChartPricesBatchNumber]);
	EndIf;

	If Areas.Find("ChartSales") <> Undefined Then
		If QueryChartSales.Show Then
			FillChartSales(Result[QueryTextChartSalesBatchNumber]);
		Else
			InitializeEmptyChartSales();
		EndIf;
	EndIf;
	
	If Areas.Find("OnHand") <> Undefined Then
		FillOnHand(Result[QueryTextOnHandBatchNumber]);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillActualPrices(Data)
	
	ActualPrices.Clear();
	
	Prices = Data.Unload();
	If Prices.Count() = 0 Then
		Items.DecorationPricesNotFilled.Visible = True;
		Return;
	Else
		Items.DecorationPricesNotFilled.Visible = False;
	EndIf;
	
	RowStructure = New Array;
	FormatString = "";
	
	Iterator = 0;
	
	For Each PriceLine In Prices Do
		
		NewRow = ActualPrices.Add();
		FillPropertyValues(NewRow, PriceLine);
		
		Color = PriceKindColor(PriceLine.PriceKind);
		
		PricesGroup = Items.Add("GroupActualPrices" + Iterator, Type("FormGroup"), Items.ActualPrices);
		PricesGroup.Type = FormGroupType.UsualGroup;
		PricesGroup.Representation = UsualGroupRepresentation.None;
		PricesGroup.ShowTitle = False;
		PricesGroup.Group = ChildFormItemsGroup.AlwaysHorizontal;
		
		RowStructure.Clear();
		RowStructure.Add(New FormattedString(PriceLine.PriceKind.Description, , Color));
		
		NewDecoration = Items.Add("ActualPricePriceKind" + Iterator, Type("FormDecoration"), PricesGroup);
		NewDecoration.Type = FormDecorationType.Label;
		NewDecoration.Title = New FormattedString(RowStructure, New Font(, 10));
		NewDecoration.AutoMaxWidth = False;
		NewDecoration.MaxWidth = 22;
		NewDecoration.HorizontalStretch = True;
		NewDecoration.Height = 1;
		NewDecoration.VerticalAlign = ItemVerticalAlign.Center;
		
		RowStructure.Clear();
		FormattedNumber = Format(PriceLine.Price, FormatString);
		RowStructure.Add(New FormattedString(FormattedNumber));
		
		NewDecoration = Items.Add("ActualPricePriceValue" + Iterator, Type("FormDecoration"), PricesGroup);
		NewDecoration.Type = FormDecorationType.Label;
		NewDecoration.Title = New FormattedString(RowStructure, New Font(, 10));
		NewDecoration.AutoMaxWidth = False;
		NewDecoration.MaxWidth = 10;
		NewDecoration.HorizontalStretch = True;
		NewDecoration.Height = 1;
		NewDecoration.HorizontalAlign = ItemHorizontalLocation.Right;
		NewDecoration.VerticalAlign = ItemVerticalAlign.Center;
		
		RowStructure.Clear();
		FormattedNumber = Format(PriceLine.Price, FormatString);
		RowStructure.Add(New FormattedString(" " + PriceLine.PriceKind.PriceCurrency.Description));
		
		NewDecoration = Items.Add("ActualPricePriceCurrency" + Iterator, Type("FormDecoration"), PricesGroup);
		NewDecoration.Type = FormDecorationType.Label;
		NewDecoration.Title = New FormattedString(RowStructure, New Font(, 10));
		NewDecoration.AutoMaxWidth = False;
		NewDecoration.MaxWidth = 6;
		NewDecoration.HorizontalStretch = True;
		NewDecoration.Height = 1;
		NewDecoration.HorizontalAlign = ItemHorizontalLocation.Right;
		NewDecoration.VerticalAlign = ItemVerticalAlign.Center;
		
		Iterator = Iterator + 1;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillChartPrices(Data)
	
	SumPriceByComponents = ItIsBundleWithPerComponentPricing(Object);
	
	ChartPrices.RefreshEnabled = False;
	
	ChartPricesDateFormat = DateFormatFromPeriodicity(ChartPricesPeriodicity);
	
	SelectionPeriod = Data.Select(QueryResultIteration.ByGroups);
	If Not ValueIsFilled(ChartPricesPeriod.StartDate) And SelectionPeriod.Count() > 0 And Not SumPriceByComponents Then
		MinPeriod = '39991231';
		MaxPeriod = '00010101';
		While SelectionPeriod.Next() Do
			MinPeriod = Min(SelectionPeriod.Period, MinPeriod);
			MaxPeriod = Max(SelectionPeriod.Period, MaxPeriod);
		EndDo;
		If ValueIsFilled(MinPeriod) Then
			ChartPricesPeriod.StartDate = MinPeriod;
		EndIf;
		If ValueIsFilled(MaxPeriod) Then
			ChartPricesPeriod.EndDate = MaxPeriod;
		EndIf;
	EndIf;
	SelectionPeriod.Reset();
	
	Filter = New Structure("Products, Characteristic", Object.Ref, Catalogs.ProductsCharacteristics.EmptyRef());
	If ValueIsFilled(ChartPricesPeriod.StartDate) And Not SumPriceByComponents Then
		BegOfInterval = BegOfInterval(ChartPricesPeriod.StartDate, ChartPricesPeriodicity);
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	PricesSliceLast.Period AS Period,
		|	PricesSliceLast.Recorder AS Recorder,
		|	PricesSliceLast.LineNumber AS LineNumber,
		|	PricesSliceLast.Active AS Active,
		|	PricesSliceLast.PriceKind AS PriceKind,
		|	PricesSliceLast.Products AS Products,
		|	PricesSliceLast.Characteristic AS Characteristic,
		|	PricesSliceLast.Price AS Price,
		|	PricesSliceLast.MeasurementUnit AS MeasurementUnit,
		|	PricesSliceLast.Author AS Author
		|FROM
		|	InformationRegister.Prices.SliceLast(&StartDate, ) AS PricesSliceLast
		|WHERE
		|	PricesSliceLast.Products = &Products
		|	AND PricesSliceLast.Characteristic = &Characteristic";
		
		Query.SetParameter("StartDate", ChartPricesPeriod.StartDate);
		Query.SetParameter("Characteristic", Filter.Characteristic);
		Query.SetParameter("Products", Filter.Products);
		
		PricesAtStartDate = Query.Execute().Unload();
		
	Else
		
		PricesAtStartDate = Undefined;
		
	EndIf;
	
	If SelectionPeriod.Count() = 0 And (PricesAtStartDate = Undefined Or PricesAtStartDate.Count() = 0) Then
		
		InitializeEmptyChartPrices();
		
	ElsIf SelectionPeriod.Count() = 0 And (PricesAtStartDate = Undefined Or PricesAtStartDate.Count() <> 0) Then
		
		InitializeChartPrices();
		
		For Each Row In PricesAtStartDate Do
			
			Point0 = ChartPrices.SetPoint(ChartPricesPeriod.StartDate);
			Point = ChartPrices.SetPoint(ChartPricesPeriod.EndDate);
			
			Point0.Text = Format(ChartPricesPeriod.StartDate, ChartPricesDateFormat);
			Point0.Text = Format(ChartPricesPeriod.EndDate, ChartPricesDateFormat);
			
			Series =ChartPrices.SetSeries(Row.PriceKind);
			Series.Marker = ChartMarkerType.None;
			Color = PriceKindColor(Row.PriceKind);
			If Color <> Undefined Then
				Series.Color = Color;
			EndIf;
			
			ChartPrices.SetValue(Point0, Series, Row.Price);
			ChartPrices.SetValue(Point, Series, Row.Price);
			
		EndDo;
		
	Else
		
		InitializeChartPrices();
		
		SeePeriodBeg = ValueIsFilled(ChartPricesPeriod.StartDate);
		
		While SelectionPeriod.Next() Do
			
			If SelectionPeriod.Count() = 1 Then
				Point0 = ChartPrices.SetPoint(SelectionPeriod.Period);
				Point0.Text = Format(SelectionPeriod.Period, ChartPricesDateFormat);
			Else
				Point0 = Undefined;
			EndIf;
			
			SelectionPriceKind = SelectionPeriod.Select();
			While SelectionPriceKind.Next() Do
				
				If SeePeriodBeg And Point0 = Undefined And PricesAtStartDate <> Undefined Then
					
					Row = PricesAtStartDate.Find(SelectionPriceKind.PriceKind, "PriceKind");
					If Row <> Undefined Then
						
						Point = ChartPrices.SetPoint(BegOfInterval);
						Point.Text = Format(BegOfInterval, ChartPricesDateFormat);
						Series = ChartPrices.SetSeries(SelectionPriceKind.PriceKind);
						ChartPrices.SetValue(Point, Series, Row.Price);
						
						PricesAtStartDate.Delete(Row);
						
					EndIf;
					
				EndIf;
				
				Series = ChartPrices.SetSeries(SelectionPriceKind.PriceKind);
				Series.Marker = ChartMarkerType.None;
				Color = PriceKindColor(SelectionPriceKind.PriceKind);
				If Color <> Undefined Then
					Series.Color = Color;
				EndIf;
				
				If Point0 <> Undefined Then
					Point = ChartPrices.SetPoint(SelectionPeriod.Period + 1);
				Else
					Point = ChartPrices.SetPoint(SelectionPeriod.Period);
				EndIf;
				
				Point.Text = Format(SelectionPeriod.Period, ChartPricesDateFormat);
				
				If Point0 <> Undefined Then
					
					Value = 0;
					
					If PricesAtStartDate <> Undefined Then
						Row = PricesAtStartDate.Find(SelectionPriceKind.PriceKind, "PriceKind");
						If Row <> Undefined Then
							Value = Row.Price;
						EndIf;
					EndIf;
					
					ChartPrices.SetValue(Point0, Series, Value);
				EndIf;
				
				ChartPrices.SetValue(Point, Series, SelectionPriceKind.Price);
				
			EndDo;
			
		EndDo;
		
		If PricesAtStartDate <> Undefined And Point0 = Undefined Then
			For Each Row In PricesAtStartDate Do
				
				If ChartPricesPeriod.EndDate <> Date(1, 1, 1) Then
					
					Point = ChartPrices.SetPoint(ChartPricesPeriod.EndDate);
					Point.Text = Format(ChartPricesPeriod.EndDate, ChartPricesDateFormat);
					
					Series = ChartPrices.SetSeries(Row.PriceKind);
					Series.Marker = ChartMarkerType.None;
					Color = PriceKindColor(Row.PriceKind);
					If Color <> Undefined Then
						Series.Color = Color;
					EndIf;
					
					ChartPrices.SetValue(Point, Series, Row.Price);
					
				EndIf;
				
			EndDo;
		EndIf;
		
		For Each Series In ChartPrices.Series Do
			
			PreviousValue = Undefined;
			Iterator = 0;
			While PreviousValue = Undefined And ChartPrices.Points.Count() > Iterator Do
				
				Point = ChartPrices.Points[Iterator];
				ChartValue = ChartPrices.GetValue(Point, Series).Value;
				If ValueIsFilled(ChartValue) Then
					PreviousValue = ChartValue;
					Break;
				EndIf;
				
				Iterator = Iterator + 1;
				
			EndDo;
			
			While ChartPrices.Points.Count() > Iterator Do
				
				Point = ChartPrices.Points[Iterator];
				ChartValue = ChartPrices.GetValue(Point, Series).Value;
				If ValueIsFilled(ChartValue) Then
					PreviousValue = ChartValue;
				Else
					ChartPrices.SetValue(Point, Series, PreviousValue);
				EndIf;
				
				Iterator = Iterator + 1;
				
			EndDo;
			
		EndDo;
		
		If Not ValueIsFilled(ChartPricesPeriod) And ChartPrices.Points.Count() Then
			ChartPricesPeriod.StartDate = ChartPrices.Points[0].Value;
			ChartPricesPeriod.EndDate = ChartPrices.Points[ChartPrices.Points.Count() - 1].Value;
		EndIf;
		
	EndIf;
	
	ChartPricesAvailablePeriods = AvailablePeriods(ChartPricesPeriod);
	ChartPricesRefreshPeriodicityButtons();
	ChartPricesSetPeriodTitle();
	
	ChartPrices.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure FillChartSales(Data)
	
	ChartSales.RefreshEnabled = False;
	ChartSalesQuantity.RefreshEnabled = False;
	
	ChartSalesDateFormat = DateFormatFromPeriodicity(ChartSalesPeriodicity);
	
	SeriesColors = DriveServer.ChartSeriesColors();
	
	Selection = Data.Select(QueryResultIteration.ByGroups);
	
	If Selection.Count() = 0 Then
		InitializeEmptyChartSales();
	Else
		InitializeChartSales();
		
		SeriesRevenue = ChartSales.Series.Add(NStr("en = 'Net sales'; ru = 'Чистые продажи';pl = 'Sprzedaż netto';es_ES = 'Ventas netas';es_CO = 'Ventas netas';tr = 'Net satışlar';it = 'Vendite nette';de = 'Nettoumsatz'"));
		SeriesRevenue.Color = SeriesColors[1];
		
		SeriesCOGS = Undefined;
		If Object.ProductsType = Enums.ProductsTypes.InventoryItem
			Or Object.ProductsType = Enums.ProductsTypes.Work Then
			
			SeriesCOGS = ChartSales.Series.Add(NStr("en = 'COGS'; ru = 'Себестоимость продаж';pl = 'KWS';es_ES = 'COGS (costo de los bienes vendidos)';es_CO = 'COGS (costo de los bienes vendidos)';tr = 'SMM';it = 'Costo del Venduto';de = 'Wareneinsatz'"));
			SeriesCOGS.Color = SeriesColors[0];
		EndIf;
		
		SeriesQuantity = ChartSalesQuantity.Series.Add(NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
		SeriesQuantity.Color = SeriesColors[0];
		
		BegOfPeriod = BegOfInterval(ChartSalesPeriod.StartDate, ChartSalesPeriodicity);
		EndOfPeriod = BegOfInterval(ChartSalesPeriod.EndDate, ChartSalesPeriodicity);
		
		CurrentPeriod = BegOfPeriod;
		
		While Selection.Next() Do
			
			While CurrentPeriod < BegOfInterval(Selection.Period, ChartSalesPeriodicity) Do
				NewPoint = ChartSales.SetPoint(CurrentPeriod);
				NewPoint.Text = Format(CurrentPeriod, ChartSalesDateFormat);
				
				NewPoint2 = ChartSalesQuantity.SetPoint(CurrentPeriod);
				NewPoint2.Text = Format(CurrentPeriod, ChartSalesDateFormat);
				
				CurrentPeriod = NextInterval(CurrentPeriod, ChartSalesPeriodicity);
			EndDo;
			
			If CurrentPeriod = BegOfInterval(Selection.Period, ChartSalesPeriodicity) Then
				CurrentPeriod = NextInterval(CurrentPeriod, ChartSalesPeriodicity);
			EndIf;
			
			NewPoint = ChartSales.SetPoint(Selection.Period);
			NewPoint.Text = Format(Selection.Period, ChartSalesDateFormat);
			
			NewPoint2 = ChartSalesQuantity.SetPoint(Selection.Period);
			NewPoint2.Text = Format(Selection.Period, ChartSalesDateFormat);
			
			COGS = Selection.COGS;
			Revenue = Selection.Revenue;
			Quantity = Selection.Quantity;
			
			ChartPoint = Undefined;
			If ChartSalesPeriodicity <> DataAnalysisTimeIntervalUnitType.Day Then
				ChartPoint = New Structure;
				ChartPoint.Insert("Period", Selection.Period);
				ChartPoint.Insert("Periodicity", ChartSalesPeriodicity);
			EndIf;
			
			If SeriesCOGS <> Undefined Then
				ChartSales.SetValue(NewPoint, SeriesCOGS, COGS, ChartPoint);
			EndIf;
			
			ChartSales.SetValue(NewPoint, SeriesRevenue, Revenue, ChartPoint);
			
			ChartSalesQuantity.SetValue(NewPoint2, SeriesQuantity, Quantity);
			
		EndDo;
		
		While CurrentPeriod <= EndOfPeriod Do
			
			NewPoint = ChartSales.SetPoint(CurrentPeriod);
			NewPoint.Text = Format(CurrentPeriod, ChartSalesDateFormat);
			
			NewPoint2 = ChartSalesQuantity.SetPoint(CurrentPeriod);
			NewPoint2.Text = Format(CurrentPeriod, ChartSalesDateFormat);
			
			CurrentPeriod = NextInterval(CurrentPeriod, ChartSalesPeriodicity);
		EndDo;
		
	EndIf;
	
	ChartSales.RefreshEnabled = True;
	ChartSalesQuantity.RefreshEnabled = True;
	
	ChartSalesAvailablePeriods = AvailablePeriods(ChartSalesPeriod);
	ChartSalesRefreshPeriodicityButtons();
	ChartSalesSetPeriodTitle();
	
EndProcedure

&AtServer
Procedure FillOnHand(Data)
	
	OnHand.GetItems().Clear();
	
	SelectionCharacteristics = Data.Select(QueryResultIteration.ByGroups);
	
	If SelectionCharacteristics.Count() = 0 Then
		Items.OnHandNotFilled.Visible = True;
		Return;
	Else
		Items.OnHandNotFilled.Visible = False;
	EndIf;
	
	Items.OnHand.Visible = True;
	CharacteristicsTree = OnHand.GetItems();
	
	While SelectionCharacteristics.Next() Do
		
		HaveCharacteristics = Catalogs.ProductsCharacteristics.Select(, Object.Ref).Next()
		Or Catalogs.ProductsCharacteristics.Select(, Object.ProductsCategory).Next();
		
		If HaveCharacteristics Then
			
			TreeNewRowCharacteristic = CharacteristicsTree.Add();
			TreeNewRowCharacteristic.Part = SelectionCharacteristics.Characteristic;
			
			OnHandStr = "" + SelectionCharacteristics.OnHand;
			Available = " / " + SelectionCharacteristics.OnHand;
			If ValueIsFilled(SelectionCharacteristics.Reserved) Then
				Available = " / " + (SelectionCharacteristics.OnHand - SelectionCharacteristics.Reserved);
			EndIf;
			
			TreeNewRowCharacteristic.Quantity = OnHandStr + Available;
			TreeNewRowCharacteristic.IsCharacteristic = True;
			
			TreeStructuralUnits = TreeNewRowCharacteristic.GetItems();
			
		Else
			
			TreeStructuralUnits = OnHand.GetItems();
			
		EndIf;
		
		SelectionStructuralUnits = SelectionCharacteristics.Select(QueryResultIteration.ByGroups);
		While SelectionStructuralUnits.Next() Do
			
			TreeNewRowStructuralUnit = TreeStructuralUnits.Add();
			
			TreeNewRowStructuralUnit.Part = SelectionStructuralUnits.StructuralUnit;
			
			OnHandStr = "" + SelectionStructuralUnits.OnHand;
			Available = " / " + SelectionStructuralUnits.OnHand;
			If ValueIsFilled(SelectionStructuralUnits.Reserved) Then
				Available = " / " + (SelectionStructuralUnits.OnHand - SelectionStructuralUnits.Reserved);
			EndIf;
			
			TreeNewRowStructuralUnit.Quantity = OnHandStr + Available;
			TreeBatches = TreeNewRowStructuralUnit.GetItems();
			
			If Object.UseBatches Then
				
				SelectionBatches = SelectionStructuralUnits.Select();
				While SelectionBatches.Next() Do
					
					TreeNewRowBatch = TreeBatches.Add();
					TreeNewRowBatch.Part = SelectionBatches.Batch;
					
					OnHandStr = "" + SelectionBatches.OnHand;
					Available = " / " + SelectionBatches.OnHand;
					If ValueIsFilled(SelectionBatches.Reserved) Then
						Available = " / " + (SelectionBatches.OnHand - SelectionBatches.Reserved);
					EndIf;
					
					TreeNewRowBatch.Quantity = OnHandStr + Available;
					TreeNewRowBatch.IsBatch = True;
					
				EndDo;
				
			EndIf;
			
		EndDo;
			
	EndDo;
	
EndProcedure

&AtServer
Function AvailablePeriods(Period)
	
	AvailablePeriods = New ValueList;
	StartDate = Period.StartDate;
	EndDate = Period.EndDate;
	
	AvailablePeriods.Add(DataAnalysisTimeIntervalUnitType.Day, NStr("en = 'days'; ru = 'дней';pl = 'dni';es_ES = 'días';es_CO = 'días';tr = 'günler';it = 'giorni';de = 'Tage'"));
	
	BegOfPeriod = BegOfWeek(EndDate);
	If BegOfPeriod > StartDate Then
		AvailablePeriods.Add(DataAnalysisTimeIntervalUnitType.Week, NStr("en = 'weeks'; ru = 'нед.';pl = 'tygodnie';es_ES = 'semanas';es_CO = 'semanas';tr = 'haftalar';it = 'settimane';de = 'Wochen'"));
	EndIf;
	
	BegOfPeriod = BegOfMonth(EndDate);
	If BegOfPeriod > StartDate Then
		AvailablePeriods.Add(DataAnalysisTimeIntervalUnitType.Month, NStr("en = 'months'; ru = 'месяцы';pl = 'miesięcy';es_ES = 'meses';es_CO = 'meses';tr = 'aylar';it = 'mesi';de = 'Monate'"));
	EndIf;
	
	BegOfPeriod = BegOfQuarter(EndDate);
	If BegOfPeriod > StartDate Then
		AvailablePeriods.Add(DataAnalysisTimeIntervalUnitType.Quarter, NStr("en = 'quarters'; ru = 'кварталов';pl = 'kwartały';es_ES = 'trimestres';es_CO = 'trimestres';tr = 'çeyrek yıl';it = 'Trimestri';de = 'Viertel'"));
	EndIf;
	
	BegOfPeriod = BegOfYear(EndDate);
	If BegOfPeriod > StartDate Then
		AvailablePeriods.Add(DataAnalysisTimeIntervalUnitType.Year, NStr("en = 'years'; ru = 'лет';pl = 'lat';es_ES = 'años';es_CO = 'años';tr = 'yıl için yedekleri depola.';it = 'anni';de = 'Jahre'"));
	EndIf;
	
	Return AvailablePeriods;
	
EndFunction

&AtServer
Function CorrectPeriodicity(StartDate, EndDate = Undefined)
	
	CurrentDate = ?(EndDate = Undefined, CurrentSessionDate(), EndDate);
	
	BegOfPeriod = BegOfYear(CurrentDate);
	If StartDate < BegOfPeriod Then
		Return DataAnalysisTimeIntervalUnitType.Year;
	EndIf;

	BegOfPeriod = BegOfQuarter(CurrentDate);
	If StartDate < BegOfPeriod Then
		Return DataAnalysisTimeIntervalUnitType.Quarter;
	EndIf;
	
	BegOfPeriod = BegOfMonth(CurrentDate);
	If StartDate < BegOfPeriod Then
		Return DataAnalysisTimeIntervalUnitType.Month;
	EndIf;
	
	BegOfPeriod = BegOfWeek(CurrentDate);
	If StartDate < BegOfPeriod Then
		Return DataAnalysisTimeIntervalUnitType.Week;
	EndIf;
	
	Return DataAnalysisTimeIntervalUnitType.Day;
	
EndFunction

&AtServer
Function BegOfInterval(Period, Periodicity)
	
	If Periodicity = DataAnalysisTimeIntervalUnitType.Year Then
		Return BegOfYear(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
		Return BegOfQuarter(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Month Then
		Return BegOfMonth(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Week Then
		Return BegOfWeek(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Day Then
		Return BegOfDay(Period);
	Else
		Return Period;
	EndIf;
	
EndFunction

&AtServer
Function EndOfInterval(Period, Periodicity)
	
	Result = Period;
	
	If Periodicity = DataAnalysisTimeIntervalUnitType.Year Then
		Result = EndOfYear(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
		Result = EndOfQuarter(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Month Then
		Result = EndOfMonth(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Week Then
		Result = EndOfWeek(Period);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Day Then
		Result = EndOfDay(Period);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function NextInterval(Period, Periodicity)
	
	Result = Period;
	
	If Periodicity = DataAnalysisTimeIntervalUnitType.Year Then
		Result = AddMonth(Period, 12);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
		Result = AddMonth(Period, 3);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Month Then
		Result = AddMonth(Period, 1);
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Week Then
		Result = Period + 86400*7;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Day Then
		Result = Period + 86400;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function PeriodTitle(Period)
	
	Result = "";
	If ValueIsFilled(Period) Then
		Result = PeriodPresentation(Period.StartDate, ?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), Period.EndDate));
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ChartPricesSetPeriodTitle()
	
	ChartPricesPeriodTitle = PeriodTitle(ChartPricesPeriod);
	
EndProcedure

&AtServer
Procedure ChartSalesSetPeriodTitle()
	
	ChartSalesPeriodTitle = PeriodTitle(ChartSalesPeriod);
	
EndProcedure

&AtServer
Procedure InitializeChartPrices()
	
	Items.ChartPrices.Enabled = True;
	Items.PricesOverviewCommandBar.Visible = True;
	
	ChartPrices.Clear();
	ChartPrices.ShowTitle = False;
	ChartPrices.PlotArea.ShowScale = True;
	ChartPrices.ShowLegend = True;
	ChartPrices.LegendArea.Placement = ChartLegendPlacement.UseCoordinates;
	ChartPrices.LegendArea.Left = 0.1;
	ChartPrices.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
EndProcedure

&AtServer
Procedure InitializeChartSales()
	
	Items.ChartSales.Enabled = True;
	Items.ChartSalesCommandBar.Visible = True;
	
	ChartSales.Clear();
	ChartSalesQuantity.Clear();
	
	ChartSales.ShowTitle = False;
	ChartSales.PlotArea.ShowScale = True;
	ChartSales.ShowLegend = True;
	ChartSales.LegendArea.Placement = ChartLegendPlacement.UseCoordinates;
	ChartSales.LegendArea.Left = 0.1;
	
	ChartSalesQuantity.ShowTitle = False;
	ChartSalesQuantity.PlotArea.ShowScale = True;
	ChartSalesQuantity.ShowLegend = True;

	ChartSales.Border = New Border(ControlBorderType.WithoutBorder, -1);
	ChartSalesQuantity.Border = New Border(ControlBorderType.WithoutBorder, -1);

EndProcedure

&AtServer
Procedure InitializeEmptyChartPrices()
	
	Items.ChartPrices.Enabled = False;
	Items.PricesOverviewCommandBar.Visible = False;
	ChartPrices.ShowTitle = True;
	ChartPrices.PlotArea.ShowScale = False;
	ChartPrices.Clear();
	
EndProcedure

&AtServer
Procedure InitializeEmptyChartSales()
	
	Items.ChartSales.Enabled = False;
	Items.ChartSalesCommandBar.Visible = False;
	ChartSales.ShowTitle = True;
	ChartSales.PlotArea.ShowScale = False;
	ChartSalesQuantity.PlotArea.ShowScale = False;
	ChartSales.Clear();
	ChartSalesQuantity.Clear();
	
EndProcedure

&AtServer
Function PriceKindColor(PriceKind)
	
	Result = Undefined;
	
	Rows = PriceKindsColors.FindRows(New Structure("PriceKind", PriceKind));
	
	If Rows.Count() <> 0 Then
		Result = Rows[0].Color;
	Else
		RowsCount = PriceKindsColors.Count();
		NewRow = PriceKindsColors.Add();
		NewRow.PriceKind = PriceKind;
		If RowsCount < 10 Then
			ChartSeriesColors = DriveServer.ChartSeriesColors();
			NewRow.Color = ChartSeriesColors[RowsCount];
		Else
			NewRow.Color = Undefined;
		EndIf;
		Result = NewRow.Color;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ChartPricesRefreshPeriodicityButtons()
	
	Items.ChartPricesByDays.Visible = 
		ChartPricesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Day) <> Undefined;
		
	Items.ChartPricesByWeeks.Visible = 
		ChartPricesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Week) <> Undefined;
		
	Items.ChartPricesByMonths.Visible = 
		ChartPricesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Month) <> Undefined;
		
	Items.ChartPricesByQuarters.Visible = 
		ChartPricesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Quarter) <> Undefined;
		
	Items.ChartPricesByYears.Visible = 
		ChartPricesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Year) <> Undefined;
	
EndProcedure

&AtServer
Procedure ChartSalesRefreshPeriodicityButtons()
	
	Items.ChartSalesByDays.Visible = 
		ChartSalesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Day) <> Undefined;
		
	Items.ChartSalesByWeeks.Visible = 
		ChartSalesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Week) <> Undefined;
		
	Items.ChartSalesByMonths.Visible = 
		ChartSalesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Month) <> Undefined;
		
	Items.ChartSalesByQuarters.Visible = 
		ChartSalesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Quarter) <> Undefined;
		
	Items.ChartSalesByYears.Visible = 
		ChartSalesAvailablePeriods.FindByValue(DataAnalysisTimeIntervalUnitType.Year) <> Undefined;
	
EndProcedure

&AtClient
Procedure SetChartsVisible()
	
	Items.FormHideCharts.Check		= HideCharts;
	Items.PricesOverview.Visible	= ValueIsFilled(Object.Ref) And Not HideCharts;
	Items.GroupChartSales.Visible	= ValueIsFilled(Object.Ref) And Not HideCharts;
	
EndProcedure

&AtServer
Function DateFormatFromPeriodicity(Periodicity)
	
	DateFormat = "";
	
	If Periodicity = DataAnalysisTimeIntervalUnitType.Day Then
		DateFormat = "DLF=D";
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Week Then
		DateFormat = "DLF=D";
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Month Then
		DateFormat = "DLF=""MMMM yyyy""";
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
		DateFormat = "DLF=""q""";
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Year Then
		DateFormat = "DLF=""yyyy""";
	EndIf;
	
	Return DateFormat;
	
EndFunction

&AtServer
Procedure ChartPricesSetPeriodicity(Periodicity)
	
	If ValueIsFilled(ChartPricesPeriodicity) Then
		
		CurrentPeriodicity = ChartPricesPeriodicity;
		
		If CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Day Then
			Items.ChartPricesByDays.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Week Then
			Items.ChartPricesByWeeks.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Month Then
			Items.ChartPricesByMonths.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
			Items.ChartPricesByQuarters.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Year Then
			Items.ChartPricesByYears.Check = False;
		EndIf;
		
	EndIf;
	
	ChartPricesPeriodicity = Periodicity;
	If Periodicity = DataAnalysisTimeIntervalUnitType.Day Then
		Items.ChartPricesByDays.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Week Then
		Items.ChartPricesByWeeks.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Month Then
		Items.ChartPricesByMonths.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
		Items.ChartPricesByQuarters.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Year Then
		Items.ChartPricesByYears.Check = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChartSalesSetPeriodicity(Periodicity)
	
	If ValueIsFilled(ChartSalesPeriodicity) Then
		
		CurrentPeriodicity = ChartSalesPeriodicity;
		
		If CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Day Then
			Items.ChartSalesByDays.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Week Then
			Items.ChartSalesByWeeks.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Month Then
			Items.ChartSalesByMonths.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
			Items.ChartSalesByQuarters.Check = False;
		ElsIf CurrentPeriodicity = DataAnalysisTimeIntervalUnitType.Year Then
			Items.ChartSalesByYears.Check = False;
		EndIf;
		
	EndIf;
	
	ChartSalesPeriodicity = Periodicity;
	If Periodicity = DataAnalysisTimeIntervalUnitType.Day Then
		Items.ChartSalesByDays.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Week Then
		Items.ChartSalesByWeeks.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Month Then
		Items.ChartSalesByMonths.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Quarter Then
		Items.ChartSalesByQuarters.Check = True;
	ElsIf Periodicity = DataAnalysisTimeIntervalUnitType.Year Then
		Items.ChartSalesByYears.Check = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChartPricesPeriodChanging(Periodicity)
	
	ChartPricesSetPeriodicity(Periodicity);
	GetFormData("ChartPrices");
	
EndProcedure

&AtServer
Procedure ChartSalesPeriodChanging(Periodicity)
	
	ChartSalesSetPeriodicity(Periodicity);
	GetFormData("ChartSales");
	
EndProcedure

&AtServer
Procedure FillPricesMap(PreviousPrices, PriceKind, SelectionComponents)
	
	PricesByPriceKind = New Map;
	SelectionComponents.Reset();
	While SelectionComponents.Next() Do
		If PricesByPriceKind.Get(SelectionComponents.Products) = Undefined Then
			PricesByPriceKind.Insert(SelectionComponents.Products, New Map);
		EndIf;
		PricesByPriceKind.Get(SelectionComponents.Products).Insert(SelectionComponents.Characteristic, 0);
	EndDo;
	PreviousPrices.Insert( PriceKind, PricesByPriceKind);
	
EndProcedure

#EndRegion

#Region ProductPictures

// The function returns the file data
//
&AtServerNoContext
Function GetFileData(PictureFile, UUID)
	
	Return AttachedFiles.GetFileData(PictureFile, UUID);
	
EndFunction

&AtServerNoContext
Procedure DeleteAttachedFile(AttachedFile)
	
	If Not ValueIsFilled(AttachedFile) Then
		Return;
	EndIf;
	
	AttachedFileObject = AttachedFile.GetObject();
	AttachedFileObject.SetDeletionMark(True);
	AttachedFileObject.Write();
	
EndProcedure

&AtServer
Procedure RefreshPicturesViewer(Val ChangedFiles = Undefined)
	
	RefreshPicturesViewer = (ChangedFiles = Undefined);
	
	If ChangedFiles <> Undefined Then
		If TypeOf(ChangedFiles) <> Type("Array") Then
			ChangedFiles = CommonClientServer.ValueInArray(ChangedFiles);
		EndIf;
		
		For Each File In ChangedFiles Do
			RefreshPicturesViewer = ShowFileInForm(File, False);
			If RefreshPicturesViewer Then
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If Not RefreshPicturesViewer Then
		Return;
	EndIf;
	
	MainPictureChanged = False;
	If ValueIsFilled(Object.PictureFile) And Common.ObjectAttributeValue(Object.PictureFile, "DeletionMark") Then
		Object.PictureFile = Undefined;
		Modified = True;
	EndIf;
	
	FillPicturesViewer();
	MovePicture(0);
	
EndProcedure

&AtServer
Procedure SetMainImageAtServer(AttachedFile)
	
	PictureFile = Undefined;
	
	If TypeOf(AttachedFile) = Type("Array") Then
		For Each AtFile In AttachedFile Do
			If ShowFileInForm(AtFile, False)  Then
				PictureFile = AtFile;
				Break;
			EndIf;
		EndDo;
	ElsIf ShowFileInForm(AttachedFile, False) Then
		PictureFile = AttachedFile;
	EndIf;
	
	If PictureFile = Undefined Or Object.PictureFile = PictureFile Then
		Object.PictureFile = Undefined;
	Else
		Object.PictureFile = PictureFile;
	EndIf;
	
	Modified = True;
	
	PictureCommandBarVisible();
	
EndProcedure

&AtServer
Procedure MovePicture(Direction)
	
	ItemNumber = CurrentPicture + Direction;
	
	If ItemNumber < 0 Or ItemNumber >= Pictures.Count() Then
		Return;
	EndIf;
	
	DataPath = StrTemplate("Pictures[%1].PictureURL", ItemNumber);
	
	PicturesCount = Items.Picture.ChildItems.Count();
	If PicturesCount = 1 Then
		PreviousPicture = Items.PictureURL;
		NewPictureNumber = 1;
	Else
		PreviousPicture = Items.Picture.ChildItems[PicturesCount - 1];
		NewPictureNumber = Number(StrReplace(PreviousPicture.Name, "PictureURL", "")) + 1;
	EndIf;
	
	NewPicture = Items.Add("PictureURL" + NewPictureNumber, Type("FormField"), Items.Picture);
	FillPropertyValues(NewPicture, Items.PictureURL, , "Visible, Border, DataPath");
	NewPicture.Border = New Border(ControlBorderType.WithoutBorder);
	NewPicture.DataPath = DataPath;
	NewPicture.SetAction("Click", "Attachable_PictureURLClick");
	CurrentPicture = ItemNumber;
	
	Items.Move(PreviousPicture.ContextMenu.ChildItems["PictureURLContextMenuAddImage"], NewPicture.ContextMenu);
	Items.Move(PreviousPicture.ContextMenu.ChildItems["PictureURLContextMenuSetMainImage"], NewPicture.ContextMenu);
	Items.Move(PreviousPicture.ContextMenu.ChildItems["PictureURLContextMenuClearImage"], NewPicture.ContextMenu);
	Items.Move(PreviousPicture.ContextMenu.ChildItems["PictureURLContextMenuViewImage"], NewPicture.ContextMenu);
	
	If PicturesCount = 1 Then
		PreviousPicture.Visible = False;
	Else
		Items.Delete(PreviousPicture);
	EndIf;
	SetPictureScroll();
	PictureCommandBarVisible();
	
EndProcedure

&AtServer
Procedure FillPicturesViewer()
	
	Pictures.Clear();
	
	// 1. File from Object.PictureFile
	If Not Object.PictureFile.IsEmpty() Then
		PictureBinaryData = URLImages(Object.PictureFile, UUID);
		If PictureBinaryData <> Undefined Then
			NewRow = Pictures.Add();
			NewRow.PictureRef = Object.PictureFile;
			NewRow.PictureURL = PictureBinaryData;
		EndIf;
	EndIf;
	
	// 2. Other files
	Files = New Array;
	FilesOperations.FillFilesAttachedToObject(Object.Ref, Files);
	For Each File In Files Do
		If ShowFileInForm(File) And File <> Object.PictureFile Then
			
			PictureBinaryData = URLImages(File, UUID);
			If PictureBinaryData <> Undefined Then
				NewRow = Pictures.Add();
				NewRow.PictureRef = File;
				NewRow.PictureURL = PictureBinaryData;
			EndIf;
			
		EndIf;
	EndDo;
	
	PicturesCount = Items.Picture.ChildItems.Count();
	ShownPicture = Items.Picture.ChildItems[PicturesCount - 1];
	ShownPicture.NonselectedPictureText = Items.PictureURL.NonselectedPictureText;
	If Pictures.Count() = 0 Then
		CurrentPicture = -1;
		ShownPicture.Border = New Border(ControlBorderType.Single);
	Else
		CurrentPicture = 0;
		ShownPicture.Border = New Border(ControlBorderType.WithoutBorder);
	EndIf;
	
	SetPictureScroll();
	PictureCommandBarVisible();
	
EndProcedure

&AtServer
Function ShowFileInForm(NewFile, CheckDeletionMark = True)
	
	AllowedExtensions = New Array;
	AllowedExtensions.Add("png");
	AllowedExtensions.Add("jpeg");
	AllowedExtensions.Add("jpg");
	
	FileProperties = Common.ObjectAttributesValues(NewFile, "FileOwner, DeletionMark, Extension");
	
	Result = True;
	
	If CheckDeletionMark And FileProperties.DeletionMark
		Or FileProperties.FileOwner <> Object.Ref
		Or AllowedExtensions.Find(FileProperties.Extension) = Undefined Then
		
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetPictureScroll()
	
	If Pictures.Count() <= 1 Then
		Items.DecorationPreviousPicture.Visible = False;
		Items.DecorationNextPicture.Visible = False;
		Items.DecorationLefIndent.Visible = True;
		Items.DecorationRightIndent.Visible = True;
	Else
		Items.DecorationPreviousPicture.Visible = True;
		Items.DecorationNextPicture.Visible = True;
		Items.DecorationLefIndent.Visible = False;
		Items.DecorationRightIndent.Visible = False;
	EndIf;
	
	If CurrentPicture = 0 Then
		Items.DecorationPreviousPicture.Enabled = False;
		Items.DecorationNextPicture.Enabled = True;
	ElsIf CurrentPicture = Pictures.Count() - 1 Then
		Items.DecorationPreviousPicture.Enabled = True;
		Items.DecorationNextPicture.Enabled = False;
	Else
		Items.DecorationPreviousPicture.Enabled = True;
		Items.DecorationNextPicture.Enabled = True;
	EndIf;
	
	ItemPictureURL = Items.Find("PictureURL1");
	If ItemPictureURL <> Undefined Then
		CurrentItem = ItemPictureURL;
	EndIf;
	
EndProcedure

&AtServer
Procedure PictureCommandBarVisible()
	
	ArePictures = Pictures.Count();
	Items.PictureURLContextMenuSetMainImage.Visible = ArePictures;
	Items.PictureURLContextMenuClearImage.Visible = ArePictures;
	Items.PictureURLContextMenuViewImage.Visible = ArePictures;
	
	ItIsMainPicture = False;
	If ArePictures Then
		ItIsMainPicture = (Pictures[CurrentPicture].PictureRef = Object.PictureFile);
	EndIf;
	
	Items.PictureURLContextMenuSetMainImage.Check = ItIsMainPicture;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtServer
Function PeriodicityString(Periodicity)
	
	LongStr = GetPredefinedValueFullName(Periodicity);
	DotPosition = StrFind(LongStr, ".");
	Return Right(LongStr, StrLen(LongStr) - DotPosition);
	
EndFunction

&AtServer
Procedure NotificationProcessingPriceChanged()
	
	ActualPriceDeleteItems();
	
	ChartPricesPeriod = Undefined;
	ChartPricesSetPeriodTitle();
	
	Areas = New Array;
	Areas.Add("ActualPrices");
	Areas.Add("ChartPrices");
	GetFormData(Areas);
	
EndProcedure

&AtClientAtServerNoContext
Function ItIsBundleWithPerComponentPricing(Object)
	Return Object.IsBundle
		And Object.BundlePricingStrategy = PredefinedValue("Enum.ProductBundlePricingStrategy.PerComponentPricing");
EndFunction

&AtClient
Function IsWork()
	
	Return (Object.ProductsType = PredefinedValue("Enum.ProductsTypes.Work"));
	
EndFunction

&AtClient
Function IsInventoryItem()
	
	Return (Object.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	
EndFunction

&AtServer
Procedure SetAdditionalUOMs()
	
	DriveClientServer.SetListFilterItem(AdditionalUOMs, "Owner", Object.Ref);
	
EndProcedure

&AtClient
Procedure AddUOMFragment(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Write();
	
	AddUOMEnd();

EndProcedure

&AtClient
Procedure AddUOMEnd()
	
	If ValueIsFilled(Object.Ref) Then
		
		FilterOwner = New Structure("Owner");
		FilterOwner.Owner = Object.Ref;
		
		UOMParameters = New Structure("FillingValues", FilterOwner);
		
		OpenForm("Catalog.UOM.ObjectForm", UOMParameters);
		
	EndIf;
	
EndProcedure

// Sets the corresponding value for the GenerateDescriptionFullAutomatically variable.
//
//
&AtClientAtServerNoContext
Function SetFlagToFormDescriptionFullAutomatically(Description, DescriptionFull)
	
	Return (Description = DescriptionFull OR IsBlankString(DescriptionFull));
	
EndFunction

// Image view procedure
//
&AtClient
Procedure SeeAttachedFile()
	
	ClearMessages();
	
	FileData = GetFileData(Pictures[CurrentPicture].PictureRef, UUID);
	AttachedFilesClient.OpenFile(FileData);
	
EndProcedure

// Procedure of the image adding for the products
//
&AtClient
Procedure AddImageAtClient()
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, save the object. Do you want to save the object?'; ru = 'Для выбора изображения необходимо сохранить объект. Сохранить?';pl = 'Aby wybrać obrazek, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Bir görsel seçmek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per selezionare una immagine, salvare l''oggetto. Salvare l''oggetto?';de = 'Um das Bild auszuwählen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("AddImageAtClientEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		AddImageAtClientFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageAtClientEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.Yes Then
		Write();
	Else
		Return
	EndIf;
	
	
	AddImageAtClientFragment();

EndProcedure

&AtClient
Procedure AddImageAtClientFragment()
	
	Var FileID, Filter;
	
	If ValueIsFilled(Object.Ref) Then
		
		FileID = New UUID;
		InsertImagesFromProducts = True;
		
		Filter = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'All Images %1|All files %2|bmp format %3|GIF format %4|JPEG format %5|PNG format %6|TIFF format %7|Icon format %8|MetaFile format %9'; ru = 'Все картинки %1|Все файлы %2|Формат bmp %3|Формат GIF %4|Формат JPEG %5|Формат PNG %6|Формат TIFF %7|Формат Icon  %8|Формат MetaFile %9';pl = 'Wszystkie obrazy %1| Wszystkie pliki%2| format bmp%3| format GIF %4| format JPEG%5| format PNG%6| format TIFF%7| format Icon %8| format MetaFile %9';es_ES = 'Todas imágenes %1|Todos archivos %2|formato bmp%3|formato GIF %4|formato JPEG %5|formato PNG %6|formato TIFF %7|formato icono %8|formato MetaArchivo %9';es_CO = 'Todas imágenes %1|Todos archivos %2|formato bmp%3|formato GIF %4|formato JPEG %5|formato PNG %6|formato TIFF %7|formato icono %8|formato MetaArchivo %9';tr = 'Tüm Görüntüler %1|Tüm dosyalar %2|bmp biçimi %3|GIF biçimi %4|JPEG biçimi %5|PNG biçimi %6|TIFF biçimi %7|Simge biçimi %8|MetaDosya biçimi %9';it = 'Tutte le immagini %1|Tutti i file %2|bmp format %3|GIF format %4|JPEG format %5|PNG format %6|TIFF format %7|Icon format %8|MetaFile format %9';de = 'Alle Bilder %1| Alle Dateien %2| bmp-Format %3| GIF-Format %4| JPEG-Format %5| PNG-Format %6| TIFF-Format %7| Icon-Format %8| MetaFile-Format %9'"),
			"(*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf)|*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf",
			"(*.*)|*.*",
			"(*.bmp*;*.dib;*.rle)|*.bmp;*.dib;*.rle",
			"(*.gif*)|*.gif",
			"(*.jpeg;*.jpg)|*.jpeg;*.jpg",
			"(*.png*)|*.png",
			"(*.tif)|*.tif",
			"(*.ico)|*.ico",
			"(*.wmf;*.emf)|*.wmf;*.emf");
		
		AttachedFilesClient.AddFiles(Object.Ref, FileID, Filter);
		
	EndIf;
	
EndProcedure

// The function returns the file (image) data
//
&AtServerNoContext
Function URLImages(PictureFile, FormID)
	
	SetPrivilegedMode(True);
	Return FilesOperations.FileData(PictureFile, FormID).BinaryFileDataRef;
	
EndFunction

#Region DuplicatesBlocking

// Procedure of processing the results of Duplicate checking closing
//
&AtClient
Procedure OnCloseDuplicateChecking(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ValueIsFilled(ClosingResult.ActionWithExistingObject) Then
				
			ModificationTableAddress = ClosingResult.ModificationTableAddress;
				
		EndIf;
		
		DuplicateRulesIndexTableAddress = ClosingResult.DuplicateRulesIndexTableAddress;
		
		If ClosingResult.ActionWithNewObject = "Create" Then
			
			NotToCheck = New Structure("NotToCheckDuplicates", True);
			ThisObject.Write(NotToCheck);
			ThisObject.Close();
			
		ElsIf ClosingResult.ActionWithNewObject = "Delete" Then
			
			If ValueIsFilled(Object.Ref) Then
				
				Object.DeletionMark = True;
				NotToCheck = New Structure("NotToCheckDuplicates", True);
				ThisObject.Write(NotToCheck);
				ThisObject.Close();
				
			Else
				
				If ChangeDuplicatesDataAtServer(ModificationTableAddress) Then
					
					ThisObject.Modified = False;
					ThisObject.Close();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ChangeDuplicatesDataAtServer(ModificationTableAddress)
	
	Cancel = False;
	ModificationTable = GetFromTempStorage(ModificationTableAddress);
	DuplicatesBlocking.ChangeDuplicatesData(ModificationTable, Cancel);
	
	Return Not Cancel;
	
EndFunction

&AtServerNoContext
Function DuplicatesTableStructureAtServer(DuplicateCheckingParameters)
	
	Return DuplicatesBlocking.DuplicatesTableStructure(DuplicateCheckingParameters);
	
EndFunction

#EndRegion

#Region Bundles

&AtServer
Procedure FillUsingInBundles()
	
	If Not FOUseProductBundles Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	BundlesComponents.BundleProduct AS BundleProduct
		|FROM
		|	InformationRegister.BundlesComponents AS BundlesComponents
		|WHERE
		|	BundlesComponents.Products = &Product
		|
		|GROUP BY
		|	BundlesComponents.BundleProduct
		|
		|ORDER BY
		|	BundleProduct";
	
	Query.SetParameter("Product", Object.Ref);
	QueryResult =Query.Execute().Unload();
	QueryBundleProducts = QueryResult.UnloadColumn("BundleProduct");
	Bundles.LoadValues(QueryBundleProducts);
	Items.Bundles.HeightInTableRows = ?(Bundles.Count() > 0, Bundles.Count(), 1);
	
EndProcedure

&AtServer
Function CanChangeIsBundleAttribute()
	
	If Object.Ref.IsEmpty() Then
		
		Return True;
		
	EndIf;
	
	CanChange = True;
	NewValue = Undefined;
	
	If Object.IsBundle And ThereAreInventoryRecords(Object.Ref) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'There are records with this product, conversion into a bundle is impossible'; ru = 'По этому товару имеются движения, преобразование в набор невозможно';pl = 'Istnieją wpisy z tym produktem, przeniesienie do zestawu jest niemożliwe';es_ES = 'Con este producto hay registros, la conversión en un paquete es imposible';es_CO = 'Con este producto hay registros, la conversión en un paquete es imposible';tr = 'Bu ürünle ilgili kayıtlar mevcut; ürün setine dönüştürülemez';it = 'Esistono registrazioni con questo articolo, impossibile convertire a kit di prodotti';de = 'Es gibt Aufzeichnungen mit diesem Produkt, eine Umwandlung in eine Artikelgruppe ist nicht möglich'"));
		
		CanChange = False;
		NewValue = False;
		
	EndIf;
	
	If Object.IsBundle Then
		
		SubordinationCatalogsChecking = SubordinationCatalogsChecking(Object.Ref);
		
		If (Object.ProductsType = Enums.ProductsTypes.InventoryItem
				OR Object.ProductsType = Enums.ProductsTypes.Work)
			AND SubordinationCatalogsChecking.HasBOM Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'The BOMs for this product exist, conversion into a bundle is impossible'; ru = 'По данному товару имеются спецификации, преобразование в набор невозможно';pl = 'Istnieją specyfikacje materiałowe dla tego produktu, przeniesienie do zestawu jest niemożliwe';es_ES = 'Las listas de materiales para este producto existen, la conversión en un paquete es imposible';es_CO = 'Las listas de materiales para este producto existen, la conversión en un paquete es imposible';tr = 'Bu ürün için ürün reçeteleri mevcut; ürün setine dönüştürülemez';it = 'Esiste la Distinta Base per questo articolo, impossibile convertire in kit di prodotti';de = 'Die Stücklisten zu diesem Produkt sind vorhanden, eine Umwandlung in eine Artikelgruppe ist nicht möglich'"));
			
			CanChange = False;
			NewValue = False;
			
		EndIf;
		
		If GetFunctionalOption("UseBatches") AND SubordinationCatalogsChecking.HasBatches Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'The batches for this product exist, conversion into a bundle is impossible'; ru = 'По данному товару имеются партии, преобразование в набор невозможно';pl = 'Istnieją partie dla tego produktu, przeniesienie do zestawu jest niemożliwe';es_ES = 'Los lotes para este producto existen, la conversión en un paquete es imposible';es_CO = 'Los lotes para este producto existen, la conversión en un paquete es imposible';tr = 'Bu ürün için partiler mevcut; ürün setine dönüştürülemez';it = 'I lotti per questo articolo esistono, impossibile convertire in kit di prodotti';de = 'Die Chargen für diesen Produktel sind vorhanden, eine Umwandlung in eine Artikelgruppe ist nicht möglich'"));
			
			CanChange = False;
			NewValue = False;
			
		EndIf;
		
		If GetFunctionalOption("UseSerialNumbers") AND SubordinationCatalogsChecking.HasSerialNumbers Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'The serial numbers for this product exist, conversion into a bundle is impossible'; ru = 'По данному товару имеются серийные номера, преобразование в набор невозможно';pl = 'Istnieje numer seryjny dla tego produktu, przeniesienie do zestawu jest niemożliwe';es_ES = 'Los números de serie de este producto existen, la conversión en un paquete es imposible.';es_CO = 'Los números de serie de este producto existen, la conversión en un paquete es imposible.';tr = 'Bu ürün için seri numaraları mevcut; ürün setine dönüştürülemez';it = 'I numeri di serie per questo articolo esistono, impossibile convertire in kit di prodotti';de = 'Die Seriennummern für diesen Produkte sind vorhanden, eine Umwandlung in eine Artikelgruppe ist nicht möglich'"));
			
			CanChange = False;
			NewValue = False;
			
		EndIf;
		
		If SubordinationCatalogsChecking.HasSubstituteGoods Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'The substitute goods for this product exist, conversion into a bundle is impossible'; ru = 'По данному товару имеются товары-заменители, преобразование в набор невозможно';pl = 'Istnieją towary zastępcze dla tego produktu, przeniesienie do zestawu jest niemożliwe';es_ES = 'Las mercaderías de reemplazo para este producto existen, la conversión en un paquete es imposible.';es_CO = 'Las mercaderías de reemplazo para este producto existen, la conversión en un paquete es imposible.';tr = 'Bu ürün için ikame mallar mevcut; ürün setine dönüştürülemez';it = 'La merce sostitutiva per questo articolo esiste, impossibile convertire in kit di prodotti';de = 'Die Ersatzwaren für diesen Produkte existieren, eine Umwandlung in eine Artikelgruppe ist nicht möglich'"));
			
			CanChange = False;
			NewValue = False;
			
		EndIf;
		
	EndIf;
	
	If NewValue <> Undefined Then
		
		Object.IsBundle = NewValue;
		
	EndIf;
	
	Return CanChange;
	
EndFunction

&AtServerNoContext
Function ThereAreInventoryRecords(Product)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Inventory.Products AS Products
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Products = &Products
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	InventoryCostLayer.Products
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	InventoryCostLayer.Products = &Products
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	InventoryInWarehouses.Products
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|WHERE
	|	InventoryInWarehouses.Products = &Products
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	LandedCosts.Products
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|WHERE
	|	LandedCosts.Products = &Products";
	
	Query.SetParameter("Products", Product);
	
	Result = Query.Execute().IsEmpty();
	
	SetPrivilegedMode(False);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function SubordinationCatalogsChecking(Product)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	BillsOfMaterials.Ref AS Ref
		|FROM
		|	Catalog.BillsOfMaterials AS BillsOfMaterials
		|WHERE
		|	BillsOfMaterials.Owner = &Product
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	ProductsBatches.Ref
		|FROM
		|	Catalog.ProductsBatches AS ProductsBatches
		|WHERE
		|	ProductsBatches.Owner = &Product
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	SerialNumbers.Ref
		|FROM
		|	Catalog.SerialNumbers AS SerialNumbers
		|WHERE
		|	SerialNumbers.Owner = &Product
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	SubstituteGoods.Products
		|FROM
		|	InformationRegister.SubstituteGoods AS SubstituteGoods
		|WHERE
		|	(SubstituteGoods.Products = &Product
		|			OR SubstituteGoods.Analog = &Product)";
	
	Query.SetParameter("Product", Product);
	QueryResult = Query.ExecuteBatch();
	
	Result = New Structure;
	Result.Insert("HasBOM",				Not QueryResult[0].IsEmpty());
	Result.Insert("HasBatches",			Not QueryResult[1].IsEmpty());
	Result.Insert("HasSerialNumbers",	Not QueryResult[2].IsEmpty());
	Result.Insert("HasSubstituteGoods", Not QueryResult[3].IsEmpty());
	
	Return Result;
	
EndFunction

&AtClient
Procedure ComponentsOfTheBundleEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return
	EndIf;
	
	Write();
	
	ComponentsOfTheBundleFragment();
	
EndProcedure

&AtClient
Procedure ComponentsOfTheBundleFragment()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("BundleProduct", Object.Ref);
	ParametersStructure.Insert("BundlePricingStrategy", Object.BundlePricingStrategy);
	ParametersStructure.Insert("UseCharacteristics", Object.UseCharacteristics);
	ParametersStructure.Insert("CheckDifferentVAT",
		(Object.BundleDisplayInPrintForms = PredefinedValue("Enum.ProductBundleDisplay.Bundle")));
	
	OpenForm("InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle", ParametersStructure, ThisObject);
	
EndProcedure

&AtServerNoContext
Function CheckDifferentVATInComponents(BundleProduct)
	
	Result = True;
	
	If Not BundleProduct.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	COUNT(DISTINCT ProductsCatalog.VATRate) AS VATRatesCount
			|FROM
			|	InformationRegister.BundlesComponents AS BundlesComponents
			|		INNER JOIN Catalog.Products AS ProductsCatalog
			|		ON BundlesComponents.Products = ProductsCatalog.Ref
			|WHERE
			|	BundlesComponents.BundleProduct = &BundleProduct";
		
		Query.SetParameter("BundleProduct", BundleProduct);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			If SelectionDetailRecords.VATRatesCount > 1 Then
				Result = False;
			EndIf;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

&AtServerNoContext
Function GetStructureCrossReference(CrossReference)
	
	StructureCrossReference = Common.ObjectAttributesValues(CrossReference, "SKU, Characteristic, Owner");
	
	StructureCrossReference.Insert("IsFillCharacteristic", ValueIsFilled(StructureCrossReference.Characteristic));
	
	Return StructureCrossReference;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

&AtServer
Procedure SetUseBatchesWarningOnEdit()
	
	If ValueIsFilled(Object.Ref)
		And Not Object.UseBatches
		And Not Common.ObjectAttributeValue(Object.Ref, "UseBatches")
		And CommonServerCall.RefsToObjectFound(Object.Ref) Then
		Items.UseBatches.WarningOnEditRepresentation = WarningOnEditRepresentation.Show;
		Items.UseBatches.WarningOnEdit = NStr("en = 'This product is already included in business documents.
			|If you enable batch tracking, a product batch will be required when a user edits such a document'; 
			|ru = 'Номенклатура уже используется в коммерческих документах.
			|Если вы включите учет по партиям, пользователям нужно будет указывать партию номенклатуры при редактировании таких документов';
			|pl = 'Ten produkt jest już zawarty w dokumentach biznesowych.
			|W razie włączenia śledzenia partii, partia produktu będzie wymagana podczas edytowania takiego dokumentu przez użytkownika';
			|es_ES = 'Este producto ya está incluido en los documentos comerciales.
			|Si activa el rastreo del lote, se requerirá un lote de productos cuando un usuario edite un documento de este tipo';
			|es_CO = 'Este producto ya está incluido en los documentos comerciales.
			|Si activa el rastreo del lote, se requerirá un lote de productos cuando un usuario edite un documento de este tipo';
			|tr = 'Bu ürün işletme belgelerine dahil edilmiş durumda.
			|Parti takibini etkinleştirirseniz, bu tür bir belge kullanıcılar tarafından düzenlendiğinde ürün partisi gerekecek';
			|it = 'Questo articolo è già incluso nei documenti aziendali. 
			|Se si attiva il tracciamento lotto, un lotto dell''articolo sarà richiesto in caso di modifica di tale documento da parte di un utente';
			|de = 'Dieses Produkt ist bereits in Geschäftsunterlagen enthalten.
			|Wenn Sie die Chargenverfolgung aktivieren, ist eine Produktcharge erforderlich, wenn ein Benutzer ein solches Dokument bearbeitet'");
	Else
		Items.UseBatches.WarningOnEditRepresentation = WarningOnEditRepresentation.Auto;
		Items.UseBatches.WarningOnEdit = "";
	EndIf;
	
EndProcedure

&AtServer
// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabled(OnProductsTypeChanged = False)
	
	Items.ChangePicture.Visible = (Object.ProductsType = Enums.ProductsTypes.InventoryItem);
	Items.Weight.Visible = (Object.ProductsType = Enums.ProductsTypes.InventoryItem);
	
	ProductsTypeNotFilled = Not ValueIsFilled(Object.ProductsType);
	
	ServiceProductsType = Object.ProductsType = Enums.ProductsTypes.Service;
	
	Items.IsFreightService.Visible = ServiceProductsType;
	
	If ValueIsFilled(Object.ProductsCategory) Then
		ProductCategoryData = Common.ObjectAttributesValues(Object.ProductsCategory,
			"UseBatches, UseCharacteristics, UseSerialNumbers");
	Else
		ProductCategoryData = New Structure("UseBatches, UseCharacteristics, UseSerialNumbers", False, False, False);
	EndIf;
	
	Items.VATRate.Visible = ProductsTypeNotFilled
		Or Object.ProductsType = Enums.ProductsTypes.InventoryItem
		Or Object.ProductsType = Enums.ProductsTypes.Service
		Or Object.ProductsType = Enums.ProductsTypes.Work;

	Items.BusinessLine.Visible				= Items.VATRate.Visible;
	Items.UseCharacteristics.Visible		= Items.VATRate.Visible
		And (ProductCategoryData.UseCharacteristics Or Object.UseCharacteristics);
	Items.OrderCompletionDeadline.Visible	= Items.VATRate.Visible;
	
	Items.Vendor.Visible = ProductsTypeNotFilled
		Or Object.ProductsType = Enums.ProductsTypes.InventoryItem
		Or Object.ProductsType = Enums.ProductsTypes.Service;
								
	Items.Subcontractor.Visible = ProductsTypeNotFilled
		Or Object.ProductsType = Enums.ProductsTypes.InventoryItem
		Or Object.ProductsType = Enums.ProductsTypes.Service;
								
	SetVisibleAndEnabledCrossReferences();
	
	Items.Warehouse.Visible = ProductsTypeNotFilled
									Or Object.ProductsType = Enums.ProductsTypes.InventoryItem;
	
	Items.Picture.Visible				= Items.Warehouse.Visible;
	Items.ReplenishmentMethod.Visible	= Items.Warehouse.Visible;
	Items.ReplenishmentDeadline.Visible	= Items.Warehouse.Visible;
	Items.Cell.Visible					= Items.Warehouse.Visible;
	Items.UseBatches.Visible			= Items.Warehouse.Visible
		And (ProductCategoryData.UseBatches Or Object.UseBatches);

	Items.Specification.Visible = ProductsTypeNotFilled
		Or (Object.ProductsType = Enums.ProductsTypes.InventoryItem
			And Constants.UseProductionSubsystem.Get())
		Or (Object.ProductsType = Enums.ProductsTypes.Work
			And Constants.UseWorkOrders.Get());
	
	Items.TimeNorm.Visible = False;
	
	Items.ConversionRate.Visible = (Object.MeasurementUnit <> Object.ReportUOM);
	Items.CountryOfOrigin.Visible = Object.ProductsType = Enums.ProductsTypes.InventoryItem;
	
	Items.UseSerialNumbers.Visible			= Items.CountryOfOrigin.Visible
		And (ProductCategoryData.UseSerialNumbers Or Object.UseSerialNumbers);
	Items.WarrantyMonthsText.Visible		= Items.CountryOfOrigin.Visible;
	Items.WriteOutTheGuaranteeCard.Visible	= Items.CountryOfOrigin.Visible;
	SetWriteOutTheGuaranteeCardAvailability();
	
	// Bundles
	If FOUseProductBundles Then
		UsedInBundles = (Bundles.Count() > 0);
		IsInventoryItem = (Object.ProductsType = Enums.ProductsTypes.InventoryItem);
		CommonClientServer.SetFormItemProperty(Items, "GroupProductBundle", "Visible", IsInventoryItem);
		CommonClientServer.SetFormItemProperty(Items, "IsBundle", "Visible", Not UsedInBundles);
		CommonClientServer.SetFormItemProperty(Items, "ComponentsOfTheBundle", "Visible", Object.IsBundle And Not UsedInBundles);
		CommonClientServer.SetFormItemProperty(Items, "GroupBundleColumns", "Visible",  Object.IsBundle And Not UsedInBundles);
		CommonClientServer.SetFormItemProperty(Items, "Bundles", "Visible", UsedInBundles);
	Else
		CommonClientServer.SetFormItemProperty(Items, "GroupProductBundle", "Visible", False);
	EndIf;
	// End Bundles
	
	If OnProductsTypeChanged Then
		
		Object.ReplenishmentDeadline	= 0;
		Object.UseSerialNumbers			= Object.UseSerialNumbers And Items.UseSerialNumbers.Visible;;
		Object.UseBatches				= Object.UseBatches And Items.UseBatches.Visible;
		Object.OrderCompletionDeadline	= 0;
		Object.TimeNorm					= 0;
		Object.IsFreightService			= False;
		
		UseProductionSubsystem	= Constants.UseProductionSubsystem.Get();
		AccountingPolicy		= InformationRegisters.AccountingPolicy.GetAccountingPolicy();
		
		If Items.VATRate.Visible Then
			Object.VATRate = AccountingPolicy.DefaultVATRate;
		EndIf;
		
		If Items.BusinessLine.Visible Then
			Object.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
		EndIf;
		
		If Items.Warehouse.Visible Then
			Object.Warehouse = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
		
		If Items.ReplenishmentMethod.Visible Then
			Object.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
		EndIf;
		
		If Not ValueIsFilled(Object.ProductsType)
			Or Object.ProductsType = Enums.ProductsTypes.InventoryItem
			Or Object.ProductsType = Enums.ProductsTypes.Work Then
			
		EndIf;
		
		If Items.ReplenishmentDeadline.Visible Then
			Object.ReplenishmentDeadline = 1;
		EndIf;
		
		If Items.OrderCompletionDeadline.Visible Then
			Object.OrderCompletionDeadline = 1;
		EndIf;
		
	EndIf;
	
	Items.OnHand.Visible = ValueIsFilled(Object.Ref);
	Items.AccessGroup.Visible = Object.VisibleToExternalUsers;
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabledCrossReferences()
	
	Items.SupplierSKU.Visible = (Items.Vendor.Visible And IsUseProductCrossReferences);
	
	If IsUseProductCrossReferences 
		And ValueIsFilled(Object.ProductCrossReference) Then
		
		SupplierSKU = Common.ObjectAttributeValue(Object.ProductCrossReference, "SKU");
		
	ElsIf IsUseProductCrossReferences 
		And Not ValueIsFilled(Object.ProductCrossReference) Then
		
		Items.Vendor.ReadOnly = False;
		SupplierSKU = NStr("en = 'Select cross-reference'; ru = 'Выберите номенклатуру поставщиков';pl = 'Zaznacz powiązane informacje';es_ES = 'Seleccione la referencia cruzada';es_CO = 'Seleccione la referencia cruzada';tr = 'Çapraz referans seç';it = 'Selezionare riferimento incrociato';de = 'Herstellerartikelnummer auswählen'");
		
	EndIf;
	
	If ValueIsFilled(Object.ProductCrossReference) 
		And Object.UseDefaultCrossReference Then
		
		Items.Vendor.ReadOnly = True;
		Items.SupplierSKU.ReadOnly = True;
		
		Items.Vendor.Width = 25;
		
		Items.Vendor.ToolTip = NStr("en = 'Supplier is populated from the settings of the default product cross-reference. 
			|To specify another Supplier, set another product cross-reference as default.'; 
			|ru = 'Поставщик автоматически заполняется из настроек номенклатуры поставщика по умолчанию.
			|Чтобы изменить поставщика, назначьте другую номенклатуру поставщика ссылкой по умолчанию.';
			|pl = 'Dostawca podstawowy jest automatycznie wypełniony z ustawień domyślnych powiązanych informacji o produkcie. 
			|Aby określić innego Dostawcę podstawowego, ustaw inne powiązane informacje o produkcie jako domyślne.';
			|es_ES = 'El proveedor se rellena a partir de la configuración de la referencia cruzada del producto por defecto. 
			|Para especificar otro proveedor, establezca otra referencia cruzada del producto por defecto.';
			|es_CO = 'El proveedor se rellena a partir de la configuración de la referencia cruzada del producto por defecto. 
			|Para especificar otro proveedor, establezca otra referencia cruzada del producto por defecto.';
			|tr = 'Tedarikçi, varsayılan ürün çapraz referansı ayarlarından doldurulur.
			|Başka bir Tedarikçi belirtmek için farklı bir ürün çapraz referansını varsayılan olarak ayarlayın.';
			|it = 'Il fornitore è popolato dalle impostazioni del riferimento incrociato predefinito dell''articolo. 
			|Per specificare un altro Fornitore, impostare un altro riferimento incrociato dell''articolo come predefinito.';
			|de = 'Lieferant wird aus den Einstellungen der Standardproduktherstellerartikelnummer automatisch übernommen. 
			|Um einen anderen Lieferanten anzugeben, legen Sie eine andere Produktherstellerartikelnummer als Standard fest.'");
		Items.SupplierSKU.ToolTip = NStr("en = 'Supplier item # is populated from the settings of the default product cross-reference. 
			|To specify another Supplier item #, set another product cross-reference as default.'; 
			|ru = 'Артикул номенклатуры поставщика автоматически заполняется из настроек номенклатуры поставщика по умолчанию.
			|Чтобы изменить артикул, назначьте другую номенклатуру поставщика ссылкой по умолчанию.';
			|pl = 'Numer pozycja dostawcy podstawowego jest automatycznie wypełniony z ustawień domyślnych powiązanych informacji o produkcie. 
			|Aby określić inny numer Pozycji dostawcy podstawowego, ustaw inne powiązane informacje o produkcie jako domyślne.';
			|es_ES = 'El artículo # del proveedor se rellena a partir de la configuración de la referencia cruzada del producto por defecto. 
			|Para especificar otro artículo # del proveedor, establezca otra referencia cruzada del producto por defecto.';
			|es_CO = 'El artículo # del proveedor se rellena a partir de la configuración de la referencia cruzada del producto por defecto. 
			|Para especificar otro artículo # del proveedor, establezca otra referencia cruzada del producto por defecto.';
			|tr = 'Tedarikçi öğesinin numarası, varsayılan ürün çapraz referansı ayarlarından doldurulur.
			|Başka bir Tedarikçi öğesi numarası belirtmek için farklı bir ürün çapraz referansını varsayılan olarak ayarlayın.';
			|it = 'L''elemento # del fornitore è popolato dalle impostazioni del riferimento incrociato dell''articolo. 
			|Per specificare un altro articolo # del fornitore, impostare un altro riferimento incrociato dell''articolo come predefinito.';
			|de = 'Die Lieferanten-Artikel-Nr. wird aus den Einstellungen der Standardproduktherstellerartikelnummer übernommen. 
			|Um eine andere Lieferanten-Artikel-Nr. festzulegen, legen Sie einen anderen Produktherstellerartikelnummer als Standard fest.'");
		Items.Vendor.ToolTipRepresentation		= ToolTipRepresentation.Button;
		Items.SupplierSKU.ToolTipRepresentation	= ToolTipRepresentation.Button;
		
	Else 
		
		Items.Vendor.ReadOnly = False;
		Items.SupplierSKU.ReadOnly = False;
		
		Items.Vendor.Width = 23;
		
		Items.Vendor.ToolTipRepresentation		= ToolTipRepresentation.None;
		Items.SupplierSKU.ToolTipRepresentation	= ToolTipRepresentation.None;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetWriteOutTheGuaranteeCardAvailability()
	
	Items.WriteOutTheGuaranteeCard.ReadOnly = (Object.GuaranteePeriod = 0);
	
EndProcedure

&AtServer
// Procedure sets the form attribute visible
// from the Use Production Subsystem options, Works.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionJobsSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		Items.Warehouse.Title = NStr("en = 'Business unit'; ru = 'Подразделение';pl = 'Jednostka biznesowa';es_ES = 'Unidad empresarial';es_CO = 'Unidad de negocio';tr = 'Ambar';it = 'Business unit';de = 'Abteilung'");
		
		// Warehouse. Setting the method of Business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			AND Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.Warehouse.ListChoiceMode = True;
			Items.Warehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			Items.Warehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
		EndIf;
		
	Else
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
			NewArray.Add(Enums.BusinessUnitsTypes.Retail);
			NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
			ArrayTypesOfBusinessUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfBusinessUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Items.Warehouse.ChoiceParameters = NewParameters;
			
		Else
			
			Items.Warehouse.Visible = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure fills the list of the product types available for selection depending on the form parameters and functional
// options
// 
&AtServer
Procedure FillListTypes()
	
	List = Items.ProductsType.ChoiceList;
	
	ProductAndServicesTypeRestriction = Undefined;
	If Not Parameters.FillingValues.Property("ProductsType", ProductAndServicesTypeRestriction) Then
		Parameters.AdditionalParameters.Property("TypeRestriction", ProductAndServicesTypeRestriction);
	EndIf;
		
	If Not ProductAndServicesTypeRestriction = Undefined Then
		If (TypeOf(ProductAndServicesTypeRestriction) = Type("Array") Or TypeOf(ProductAndServicesTypeRestriction) = Type("FixedArray")) 
			AND ProductAndServicesTypeRestriction.Count() > 0 Then
			
			List.Clear();
			For Each Type In ProductAndServicesTypeRestriction Do
				List.Add(Type);
			EndDo;
			
		ElsIf TypeOf(ProductAndServicesTypeRestriction) = Type("EnumRef.ProductsTypes") Then
			
			List.Clear();
			List.Add(ProductAndServicesTypeRestriction);
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Object.ProductsType) 
		Or Items.ProductsType.ChoiceList.FindByValue(Object.ProductsType) = Undefined Then
			Object.ProductsType = List.Get(0).Value;
	EndIf;
	
	If List.Count() = 1 Then
		Items.ProductsType.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateProductSegments(Command)
	
	ClearMessages();
	ExecutionResult = GenerateProductSegmentsAtServer();
	If Not ExecutionResult.JobCompleted Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region BackgroundJobs

&AtServer
Function GenerateProductSegmentsAtServer()
	
	ProductsSegmentsJobID = Undefined;
	
	ProcedureName = "SegmentsServer.ExecuteProductSegmentsGeneration";
	ExecutionResult = TimeConsumingOperations.StartBackgroundExecution(
		UUID,
		ProcedureName,
		,
		NStr("en = 'Products segments generation'; ru = 'Генерирование сегментов номенклатуры';pl = 'Generacja segmentów produktów';es_ES = 'Generación de segmentos de productos';es_CO = 'Generación de segmentos de productos';tr = 'Ürün segmenti oluşturma';it = 'Generazione segmenti articoli';de = 'Produktsegmentgenerierung'"));
		
	StorageAddress = ExecutionResult.StorageAddress;
	ProductsSegmentsJobID = ExecutionResult.JobID;
	
	If ExecutionResult.JobCompleted Then
		MessageText = NStr("en = 'Products segments have been updated successfully.'; ru = 'Сегменты номенклатуры успешно обновлены.';pl = 'Segmenty produktów zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de productos.';es_CO = 'Se han actualizado con éxito los segmentos de productos.';tr = 'Ürün segmentleri başarıyla güncellendi.';it = 'I segmenti articolo sono stati aggiornati con successo.';de = 'Die Produktsegmente wurden erfolgreich aktualisiert.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(ProductsSegmentsJobID) Then
			MessageText = NStr("en = 'Products segments have been updated successfully.'; ru = 'Сегменты номенклатуры успешно обновлены.';pl = 'Segmenty produktów zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de productos.';es_CO = 'Se han actualizado con éxito los segmentos de productos.';tr = 'Ürün segmentleri başarıyla güncellendi.';it = 'I segmenti articolo sono stati aggiornati con successo.';de = 'Die Produktsegmente wurden erfolgreich aktualisiert.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution",
				IdleHandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(ProductsSegmentsJobID)
	
	Return TimeConsumingOperations.JobCompleted(ProductsSegmentsJobID);
	
EndFunction

#EndRegion

#EndRegion
