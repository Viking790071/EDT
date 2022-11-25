#Region ServiceProceduresAndFunctions

// <Function description>
//
// Parameters
//  <Parameter1>  - <Type.Kind> - <parameter
//                 description> <parameter description
//  continuation> <Parameter2>  - <Type.Kind> - <parameter
//                 description> <parameter description continuation>
//
// Returns:
//   <Type.Kind>   - <returned value description>
//
&AtServer
Function SetDCSFilterItem(SettingsComposer, ParameterName, ParameterValue, Use = True)

	FoundItem = Undefined;
	
	Field = New DataCompositionField(ParameterName);
	
	Filter = SettingsComposer.Settings.Filter;
	For Each FilterItem In Filter.Items Do
		If FilterItem.LeftValue = Field Then
			FoundItem = FilterItem;
		EndIf;
	EndDo;
	
	If FoundItem = Undefined Then
		FoundItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	EndIf;
	
	If TypeOf(ParameterValue) = Type("Array") Then
		FoundItem.ComparisonType = DataCompositionComparisonType.InList;
		ValueList = New ValueList;
		ValueList.LoadValues(ParameterValue);
		RightValue = ValueList;
	Else
		FoundItem.ComparisonType = DataCompositionComparisonType.Equal;
		RightValue = ParameterValue;
	EndIf;
	
	FoundItem.Use  = Use;
	FoundItem.LeftValue  = Field;
	FoundItem.RightValue = RightValue;
	
	Return FoundItem;

EndFunction

// Procedure imports filter settings from the default settings.
//
&AtServer
Procedure ImportFilterSettingsByDefault()
	
	DataCompositionSchema = DataProcessors.PrintLabelsAndTags.GetTemplate("TemplateFields");
	SettingsComposer.Initialize(
		New DataCompositionAvailableSettingsSource(PutToTempStorage(DataCompositionSchema, UUID))
	);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
EndProcedure

// Form OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// The PrintingParameter parameter is created as error bypass of platform 8.3.5. on creating the form attribute.
	
	ImportFilterSettingsByDefault();
	
	If ValueIsFilled(Parameters.AddressInStorage) Then
		
		DataStructure = GetFromTempStorage(Parameters.AddressInStorage);
		
		Object.SourceData.Load(DataStructure.Inventory);
		
		If ValueIsFilled(DataStructure.ActionsStructure) Then
			
			ActionParameter = Undefined;
			
			If DataStructure.ActionsStructure.Property("FillCompany", ActionParameter) Then
				Object.Company = ActionParameter;
			EndIf;
			
			If DataStructure.ActionsStructure.Property("FillWarehouse", ActionParameter) Then
				SetDCSFilterItem(SettingsComposer, "StructuralUnit", ActionParameter, True);
			EndIf;
			
			If DataStructure.ActionsStructure.Property("FillKindPrices", ActionParameter) Then
				Object.PriceKind = ActionParameter;
			EndIf;
			
			If DataStructure.ActionsStructure.Property("ShowColumnNumberOfDocument", ActionParameter) Then
				Items.InventoryDocumentQuantity.Visible = ActionParameter;
			EndIf;
			
			If DataStructure.ActionsStructure.Property("SetPrintModeFromDocument", ActionParameter) Then
				PrintFromDocument = True;
				Items.Settings.Visible = False;
			EndIf;
			
			FillLabelsQuantityByDocument        = DataStructure.ActionsStructure.Property("FillLabelsQuantityByDocument", ActionParameter);
			FillLabelsQuantityOnInventory = DataStructure.ActionsStructure.Property("FillLabelsQuantityOnInventory", ActionParameter);
			FillOutPriceTagsQuantityOnDocument        = DataStructure.ActionsStructure.Property("FillOutPriceTagsQuantityOnDocument", ActionParameter);
			FillPriceTagsQuantityOnInventory = DataStructure.ActionsStructure.Property("FillPriceTagsQuantityOnInventory", ActionParameter);
			
			If DataStructure.ActionsStructure.Property("FillProductsTable", ActionParameter) Then
				FillProductsTableAtServer(False);
			EndIf;
			
			If DataStructure.ActionsStructure.Property("SetMode", ActionParameter) Then
				SetMode(ActionParameter);
			Else
				Raise NStr("en = 'Print mode is not set'; ru = 'Режим печати не установлен';pl = 'Tryb drukuj nie jest ustalony';es_ES = 'Modo de impresión no está establecido';es_CO = 'Modo de impresión no está establecido';tr = 'Yazdırma modu ayarlanmamış';it = 'La modalità di stampa non è impostata';de = 'Druckmodus ist nicht eingestellt'");;
			EndIf;
			
		EndIf;
		
	Else
		
		// DataProcessor Call from interface
		FillLabelsQuantityByDocument        = False;
		FillLabelsQuantityOnInventory = True;
		FillOutPriceTagsQuantityOnDocument        = False;
		FillPriceTagsQuantityOnInventory = True;
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Object.Company = SettingValue;
		Else
			Object.Company = Catalogs.Companies.MainCompany;
		EndIf;
		
		If Constants.AccountingBySubsidiaryCompany.Get() Then
			Object.Company = Constants.ParentCompany.Get();
		EndIf;
		
		SetModeTagsPrintingAndLabelsAtServer();
		
	EndIf;
	
	If FillPriceTagsQuantityOnInventory
	AND Not FillOutPriceTagsQuantityOnDocument Then
		FillingModePriceLabelRadioButton = "Fill in with balances";
	EndIf;
	
	If Not FillPriceTagsQuantityOnInventory
	AND FillOutPriceTagsQuantityOnDocument Then
		FillingModePriceLabelRadioButton = "Fill out from document";
	EndIf;
	
	If Not FillPriceTagsQuantityOnInventory
	AND Not FillOutPriceTagsQuantityOnDocument Then
		FillingModePriceLabelRadioButton = "Do not fill";
	EndIf;
	
	If FillLabelsQuantityOnInventory
	AND Not FillLabelsQuantityByDocument Then
		FillingModeTagsRadioButton = "Fill in with balances";
	EndIf;
	
	If Not FillLabelsQuantityOnInventory
	AND FillLabelsQuantityByDocument Then
		FillingModeTagsRadioButton = "Fill out from document";
	EndIf;
	
	If Not FillLabelsQuantityOnInventory
	AND Not FillLabelsQuantityByDocument Then
		FillingModeTagsRadioButton = "Do not fill";
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

#EndRegion

#Region CommandHandlers

&AtClient
Function ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal)
	
	If Quantity < CountTotal Then
		
		Text = Text
			+ ?(Text <> "", Chars.LF, "")
			+ NStr("en = 'Selection mark is set for %QuantitySelected% lines from %QuantityTotal%.'; ru = 'Отметка выбора установлена для %QuantitySelected% строк из %QuantityTotal%.';pl = 'Znacznik wyboru jest ustawiony dla %QuantitySelected% wierszy od %QuantityTotal%.';es_ES = 'Marca de selección está establecida para %QuantitySelected% las líneas de %QuantityTotal%.';es_CO = 'Marca de selección está establecida para %QuantitySelected% las líneas de %QuantityTotal%.';tr = 'Seçim işareti %QuantityTotal% öğesinden%QuantitySelected% satırı için ayarlandı.';it = 'Il contrassegno di selezione è impostato per %QuantitySelected% lines from %QuantityTotal%.';de = 'Die Auswahlmarkierung ist auf %QuantitySelected% Zeilen aus %QuantityTotal% gesetzt.'");
		
		Text = Text
			+ Chars.LF
			+ NStr("en = 'Check: either the quantity is not filled in or the price tag (label) template is not specified. In this case, selection mark for lines cannot be specified.'; ru = 'Проверьте: не заполнены либо количество, либо не задан шаблон ценника (этикетки). В этом случае отметка выбора для строк не может быть установлена.';pl = 'Sprawdź: albo ilość nie jest wypełniona, albo szablon ceny (etykiety) nie jest określony. W tym przypadku nie można określić znacznika wyboru dla wierszy.';es_ES = 'Revisar: o la cantidad no está rellenada, o el modelo de etiquetas de precios (etiqueta) no está especificado. En este caso, la marca de selección para líneas no puede especificarse.';es_CO = 'Revisar: o la cantidad no está rellenada, o el modelo de etiquetas de precios (etiqueta) no está especificado. En este caso, la marca de selección para líneas no puede especificarse.';tr = 'Kontrol edin: miktar doldurulmaz veya fiyat etiketi (etiket) şablonu belirtilmemiş. Bu durumda, satırlar için seçim işareti belirtilemez.';it = 'Controllare: o la quantità non è stata compilata o il cartellino del prezzo (etichetta) modello non è specificato. In questo caso, il marchio di selezione per le linee non può essere specificato.';de = 'Prüfung: Entweder ist die Menge nicht ausgefüllt oder die Preisschild- (Etiketten-) Vorlage ist nicht angegeben. In diesem Fall kann die Auswahlmarkierung für Linien nicht angegeben werden.'");
		
		Text = StrReplace(Text, "%QuantitySelected%", Quantity);
		Text = StrReplace(Text, "%QuantityTotal%", CountTotal);
		
		CommonClientServer.MessageToUser(Text);
		
	EndIf;
	
EndFunction

// Procedure is opened by clicking the Select payments button.
//
&AtClient
Procedure ChooseLines()
	
	Quantity = 0;
	
	For Each TSRow In Object.Inventory Do
		
		TSRow.Selected = CheckProductChoicePossibility(TSRow, Mode);
		
		If TSRow.Selected Then
			Quantity = Quantity + 1;
		EndIf;
		
	EndDo;
	
	CountTotal = Object.Inventory.Count();
	
	ShowUserAlertAboutPossibleError("", Quantity, CountTotal);
	
EndProcedure

// Procedure is opened by clicking the Exclude payment request button.
//
&AtClient
Procedure ExcludeRows()
	
	For Each TSRow In Object.Inventory Do
		TSRow.Selected = False
	EndDo;
	
EndProcedure

// Procedure is opened by clicking the Select predefined payments button.
//
&AtClient
Procedure ChooseHighlightedLines(Command)
	
	Quantity = 0;
	
	RowArray = Items.Inventory.SelectedRows;
	For Each LineNumber In RowArray Do
		
		TSRow = Object.Inventory.FindByID(LineNumber);
		TSRow.Selected = CheckProductChoicePossibility(TSRow, Mode);
		
		If TSRow.Selected Then
			Quantity = Quantity + 1;
		EndIf;
		
	EndDo;
	
	CountTotal = RowArray.Count();
	
	ShowUserAlertAboutPossibleError("", Quantity, CountTotal);
	
EndProcedure

// Procedure is opened by clicking the Delete selected payments button.
//
&AtClient
Procedure ExcludeSelectedRows(Command)
	
	RowArray = Items.Inventory.SelectedRows;
	For Each LineNumber In RowArray Do
		TSRow = Object.Inventory.FindByID(LineNumber);
		TSRow.Selected = False;
	EndDo;
	
EndProcedure

// Procedure fills out the Inventory tabular section.
//
&AtServer
Procedure FillProductsTableAtServer(CheckFilling = True)
	
	If CheckFilling AND CheckFilling() = False Then
		Return;
	EndIf;
	
	// Necessary fields for output in the products table on a form.
	SettingsStructure = DataProcessors.PrintLabelsAndTags.GetEmptySettingsStructure();
	
	SettingsStructure.MandatoryFields.Add("Price");
	SettingsStructure.MandatoryFields.Add("Barcode");
	SettingsStructure.MandatoryFields.Add("Quantity");
	SettingsStructure.MandatoryFields.Add("Products");
	If GetFunctionalOption("UseCharacteristics") Then
		SettingsStructure.MandatoryFields.Add("Characteristic");
	EndIf;
	If GetFunctionalOption("UseBatches") Then
		SettingsStructure.MandatoryFields.Add("Batch");
	EndIf;
	SettingsStructure.MandatoryFields.Add("BalanceAtWarehouse");
	
	// Templates of labels and price tags.
	SettingsStructure.MandatoryFields.Add("Products.ProductsKind.LabelTemplate");
	SettingsStructure.MandatoryFields.Add("Products.ProductsKind.PriceTagsTemplate");
	
	SettingsStructure.DataParameters.Insert("PriceKind"    , Object.PriceKind);
	SettingsStructure.DataParameters.Insert("StructuralUnit", Object.StructuralUnit);
	SettingsStructure.DataParameters.Insert("Company", DriveServer.GetCompany(Object.Company));
	SettingsStructure.SettingsComposer = SettingsComposer;
	
	If Object.SourceData.Count() > 0 OR PrintFromDocument Then
		SettingsStructure.DataCompositionSchemaTemplateName = "TemplateFieldsDocument";
		SettingsStructure.SourceData = Object.SourceData.Unload();
	Else
		SettingsStructure.DataCompositionSchemaTemplateName = "DBTemplateFields";
	EndIf;
	
	Object.Inventory.Clear();
	
	// Import of the generated product list.
	ResultStructure = DataProcessors.PrintLabelsAndTags.PrepareDataStructure(SettingsStructure);
	For Each TSRow In ResultStructure.ProductsTable Do
		
		NewRow = Object.Inventory.Add();
		NewRow.Products         = TSRow.Products;
		
		If GetFunctionalOption("UseCharacteristics") Then
			NewRow.Characteristic       = TSRow.Characteristic;
		EndIf;
		If GetFunctionalOption("UseBatches") Then
			NewRow.Batch             = TSRow.Batch;
		EndIf;
		
		NewRow.Price                 = TSRow.Price;
		NewRow.Barcode             = TSRow.Barcode;
		NewRow.BalanceAtWarehouse      = TSRow.BalanceAtWarehouse;
		NewRow.QuantityInDocument = TSRow.Quantity;
		
		// Calculating Labels quantity.
		If FillLabelsQuantityByDocument AND Not FillLabelsQuantityOnInventory Then
			NewRow.LabelsQuantity = NewRow.QuantityInDocument;
		ElsIf FillLabelsQuantityByDocument AND FillLabelsQuantityOnInventory Then
			NewRow.LabelsQuantity = ?(NewRow.QuantityInDocument > NewRow.BalanceAtWarehouse,NewRow.BalanceAtWarehouse,NewRow.QuantityInDocument);
		ElsIf Not FillLabelsQuantityByDocument AND FillLabelsQuantityOnInventory Then
			NewRow.LabelsQuantity = ?(NewRow.BalanceAtWarehouse > 0, NewRow.BalanceAtWarehouse, 0);
		EndIf;
		
		// Calculation of Price Tags quantity.
		If FillOutPriceTagsQuantityOnDocument AND Not FillPriceTagsQuantityOnInventory Then
			NewRow.PriceTagsQuantity = 1;
		ElsIf FillOutPriceTagsQuantityOnDocument AND FillPriceTagsQuantityOnInventory Then
			NewRow.PriceTagsQuantity = ?(NewRow.BalanceAtWarehouse > 0, 1, 0);
		ElsIf Not FillOutPriceTagsQuantityOnDocument AND FillPriceTagsQuantityOnInventory Then
			NewRow.PriceTagsQuantity = ?(NewRow.BalanceAtWarehouse > 0, 1, 0);
		EndIf;
		
		NewRow.Selected = CheckProductChoicePossibility(NewRow, Mode);
		
	EndDo;
	
	Items.Inventory.Refresh();
	
EndProcedure

// Procedure - command handler "FillProductsTable".
//
&AtClient
Procedure FillInventoryTable(Command)
	
	If Object.Inventory.Count()>0 Then
		QuestionText = NStr("en = 'Manual changes will be lost. Do you want to continue?'; ru = 'Изменения, выполненные вручную, будут потеряны. Продолжить?';pl = 'Ręczne zmiany zostaną utracone. Czy chcesz kontynuować?';es_ES = 'Los cambios de manual se perderá. ¿Quiere continuar?';es_CO = 'Los cambios de manual se perderá. ¿Quiere continuar?';tr = 'Manuel değişiklikler kaybolacak. Devam etmek istiyor musunuz?';it = 'I cambiamenti manuali andranno persi. Volete continuare?';de = 'Manuelle Änderungen gehen verloren. Möchten Sie fortsetzen?'");
		ShowQueryBox(New NotifyDescription("FillInventoryTableEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo,,DialogReturnCode.Yes);
	Else
		FillProductsTableAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInventoryTableEnd(Result, AdditionalParameters) Export
    
    If DialogReturnCode.Yes = Result Then
        FillProductsTableAtServer();
    EndIf;

EndProcedure

// Procedure - handler of the Print command
//
&AtClient
Procedure Print(Command)
	
	SelectedRows = Object.Inventory.FindRows(New Structure("Selected", True));
	
	If SelectedRows.Count() = 0 Then
		
		ShowMessageBox(Undefined,NStr("en = 'No goods selected'; ru = 'Не выбрано ни одного товара';pl = 'Nie wybrano żadnego towaru';es_ES = 'No hay mercancías seleccionadas';es_CO = 'No hay mercancías seleccionadas';tr = 'Ürün seçilmedi';it = 'Nessuna merce selezionata';de = 'Keine Waren ausgewählt'"));
		Return;
		
	EndIf;
	
	If CheckFilling() Then
		
		PrintInfo = New Array;   // Add labels and price tags dataprocessor printing object in the printing parameters array.
		PrintInfo.Add(Object); // We will access the object using CommandParameter[0]
		
		TemplateNames = "";
		
		If Mode = "TagsAndLabePrinting" Then
			IsPriceLabelsNumber = False;
			IsPriceTagTemplate = False;
			IsTagNumber = False;
			IsTagTemplate = False;
			For Each CurRow In SelectedRows Do
				If CurRow.PriceTagsQuantity > 0 Then
					IsPriceLabelsNumber = True;
				EndIf;
				If ValueIsFilled(CurRow.PriceTagsTemplate) Then
					IsPriceTagTemplate = True;
				EndIf;
				If CurRow.LabelsQuantity > 0 Then
					IsTagNumber = True;
				EndIf;
				If ValueIsFilled(CurRow.LabelTemplate) Then
					IsTagTemplate = True;
				EndIf;
			EndDo;
			If IsPriceLabelsNumber
			   AND IsPriceTagTemplate
			   AND IsTagNumber
			   AND IsTagTemplate Then
				TemplateNames = "Price Tags,Labels";
			ElsIf IsTagNumber
			   AND IsTagTemplate Then
				TemplateNames = "Labels";
			Else
				TemplateNames = "Price Tags";
			EndIf;
		ElsIf Mode = "TagsPrinting" Then
			TemplateNames = "Price Tags";
		ElsIf Mode = "LabelsPrinting" Then
			TemplateNames = "Labels";
		EndIf;
		
		PrintParameters =New Structure;
		PrintParameters.Insert("FormTitle", NStr("en = 'Price tags and labels'; ru = 'Печать этикеток и ценников';pl = 'Wydruk cenników i etykiet';es_ES = 'Etiquetas de precios y etiquetas';es_CO = 'Etiquetas de precios y etiquetas';tr = 'Fiyat etiketleri ve etiketler';it = 'Stampa i cartellini dei prezzi ed etichette';de = 'Preisschilder und Etiketten'"));
		PrintParameters.Insert("PrintInfo", PrintInfo);
		
		CommandParameter = New Array;
		CommandParameter.Add(PredefinedValue("Catalog.LabelsAndTagsTemplates.EmptyRef"));
        
        PrintParameters.Insert("ID", Undefined);
        
		PrintManagementClient.ExecutePrintCommand("DataProcessor.PrintLabelsAndTags", TemplateNames, CommandParameter, ThisForm, PrintParameters);
		
	EndIf;
	
EndProcedure

// Procedure - form OnSaveDataInSettingsAtServer event hadler.
//
&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	If SavedSettings <> Undefined Then
		
		For Each KeyAndValue In SavedSettings Do
			// Inverse name conversion for map key storage in the structure
			KeyName = StrReplace(KeyAndValue.Key,"_QTQ_",".");
			KeyName = StrReplace(KeyName,"_QPQ_"," ");
			If KeyName = "_QQQ_" Then
				KeyName = "";
			EndIf;
			Settings.Insert(KeyName, KeyAndValue.Value);
		EndDo;
		
	Else
		
		// Filter is saved only if it is not print from document
		Settings.Insert("SettingsOFFilter",New ValueStorage(SettingsComposer.Settings));
		
	EndIf;
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("AddressInStorage") AND ValueIsFilled(Parameters.AddressInStorage) Then
		
		SavedSettings = New Structure;
		For Each KeyAndValue In Settings Do
			// Conversion of a name for map key storage in the structure
			KeyName = StrReplace(KeyAndValue.Key,".","_QTQ_");
			KeyName = StrReplace(KeyName," ","_QPQ_");
			If KeyName = "" Then
				KeyName = "_QQQ_";
			EndIf;
			SavedSettings.Insert(KeyName, KeyAndValue.Value);
		EndDo;
		
		Settings.Clear();
		
	Else
		
		
		SettingsOFFilter = Settings.Get("SettingsOFFilter");
		If SettingsOFFilter <> Undefined Then
			SettingsComposer.LoadSettings(SettingsOFFilter.Get());
		Else
			ImportFilterSettingsByDefault();
		EndIf;
		
		Mode = Settings.Get("Mode");
		If ValueIsFilled(Mode) Then
			SetMode(Mode);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function CheckProductChoicePossibility(CurrentData, Mode)
	
	If Mode = "TagsAndLabePrinting" Then
	
		If (CurrentData.PriceTagsQuantity = 0)
			AND CurrentData.LabelsQuantity = 0 Then
			
			Return False;
			
		ElsIf Not ValueIsFilled(CurrentData.PriceTagsTemplate)
			AND Not ValueIsFilled(CurrentData.LabelTemplate) Then
			
			Return False;
			
		ElsIf (ValueIsFilled(CurrentData.PriceTagsTemplate)
			      AND Not ValueIsFilled(CurrentData.LabelTemplate)
			      AND CurrentData.LabelsQuantity <> 0
			      AND CurrentData.PriceTagsQuantity = 0) Then

			Return False;
			
		ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
			      AND ValueIsFilled(CurrentData.LabelTemplate)
			      AND CurrentData.LabelsQuantity = 0
			      AND CurrentData.PriceTagsQuantity <> 0) Then
			
			Return False;
			
		Else
			
			Return True;
			
		EndIf;
	
	ElsIf Mode = "LabelsPrinting" Then
		
		If CurrentData.LabelsQuantity = 0 OR Not ValueIsFilled(CurrentData.LabelTemplate) Then
			Return False;
		Else
			Return True;
		EndIf;
		
	ElsIf Mode = "TagsPrinting" Then
		
		If CurrentData.PriceTagsQuantity = 0 OR Not ValueIsFilled(CurrentData.PriceTagsTemplate) Then
			Return False;
		Else
			Return True;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	CellName = Item.CurrentItem.Name;
	If CellName = "InventoryProducts" OR CellName = "InventoryCharacteristic" 
		OR CellName = "InventoryBatch" Then
	
		ShowValue(,Items.Inventory.CurrentData.Products);
	
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the PriceTagsQuantity fields of the Inventory tabular section.
//
&AtClient
Procedure InventoryPriceTagsQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure

// Procedure - handler of the OnChange event of the LabelsQuantity field of the Inventory tabular section.
//
&AtClient
Procedure InventoryLabelsQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure

// Procedure - handler of the OnChange event of the PriceTagTemplate field of the Inventory tabular section.
//
&AtClient
Procedure InventoryPriceTagsTemplateOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure

// Procedure - handler of the OnChange event of the LabelTemplate field of the Inventory tabular section.
//
&AtClient
Procedure InventoryLabelTemplateOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure

// Procedure - handler of the OnChange event of the Selected field of the Inventory tabular section.
//
&AtClient
Procedure InventoryChosenOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentRow = CurrentData.LineNumber - 1;
	
	If CurrentData.Selected Then
		
		ClearMessages();
		
		CurrentData.Selected = True;
		
		If Mode = "TagsAndLabePrinting" Then
			
			If (ValueIsFilled(CurrentData.PriceTagsTemplate)
					AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					AND Not ValueIsFilled(CurrentData.LabelTemplate)
					AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of price tags.'; ru = 'Укажите количество ценников.';pl = 'Należy wybrać liczbę cenników.';es_ES = 'Especifique la cantidad de las etiquetas de precio.';es_CO = 'Especifique la cantidad de las etiquetas de precio.';tr = 'Fiyat etiketi sayısını belirtin.';it = 'Specifica il numero di cartellini di prezzo.';de = 'Geben Sie die Anzahl der Preisschilder an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND    ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify a price tag template.'; ru = 'Укажите шаблон ценника.';pl = 'Należy wybrać szablon cennika.';es_ES = 'Especifique el modelo de la etiqueta de precio.';es_CO = 'Especifique el modelo de la etiqueta de precio.';tr = 'Bir fiyat etiketi şablonu belirtin.';it = 'Specifica il template del cartellino di prezzo.';de = 'Geben Sie eine Preisschild-Vorlage an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND    ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of labels.'; ru = 'Укажите количество этикеток.';pl = 'Należy wybrać liczbę etykiet.';es_ES = 'Especifique la cantidad de etiquetas.';es_CO = 'Especifique la cantidad de etiquetas.';tr = 'Etiket sayısını belirtin.';it = 'Specifica il numero di etichette.';de = 'Geben Sie die Anzahl der Etiketten an.'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND    ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify a label template.'; ru = 'Укажите шаблон этикетки.';pl = 'Należy wybrać szablon etykiety.';es_ES = 'Especifique el modelo de la etiqueta.';es_CO = 'Especifique el modelo de la etiqueta.';tr = 'Bir etiket şablonu belirtin.';it = 'Specifica un template etichetta.';de = 'Geben Sie eine Etikettenvorlage an.'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (   ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND    ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of labels or price tags.'; ru = 'Укажите количество этикеток или ценников.';pl = 'Należy wybrać liczbę etykiet lub cenników.';es_ES = 'Especifique la cantidad de etiquetas o las etiquetas de precio.';es_CO = 'Especifique la cantidad de etiquetas o las etiquetas de precio.';tr = 'Etiket veya fiyat etiketi sayısını belirtin.';it = 'Specifica il numero di etichette o cartellini di prezzo.';de = 'Geben Sie die Anzahl der Etiketten oder Preisschilder an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND    ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND    ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify a label or price tag template.'; ru = 'Укажите шаблон этикеток или ценников.';pl = 'Należy wybrać szablon etykiety lub cenników.';es_ES = 'Especifique la etiqueta o el modelo de la etiqueta de precio.';es_CO = 'Especifique la etiqueta o el modelo de la etiqueta de precio.';tr = 'Bir etiket veya fiyat etiketi şablonu belirtin.';it = 'Specifica un template per etichetta o cartellino prezzo.';de = 'Geben Sie eine Etiketten- oder Preisschild-Vorlage an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of labels or price tags.'; ru = 'Укажите количество этикеток или ценников.';pl = 'Należy wybrać liczbę etykiet lub cenników.';es_ES = 'Especifique la cantidad de etiquetas o las etiquetas de precio.';es_CO = 'Especifique la cantidad de etiquetas o las etiquetas de precio.';tr = 'Etiket veya fiyat etiketi sayısını belirtin.';it = 'Specifica il numero di etichette o cartellini di prezzo.';de = 'Geben Sie die Anzahl der Etiketten oder Preisschilder an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (   ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND    ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of price tags, and a label template.'; ru = 'Укажите количество ценников и шаблон этикеток.';pl = 'Należy wybrać liczbę cenników i szablonów etykiet.';es_ES = 'Especifique la cantidad de las etiquetas de precio y el modelo de la etiqueta.';es_CO = 'Especifique la cantidad de las etiquetas de precio y el modelo de la etiqueta.';tr = 'Fiyat etiketi sayısını ve etiket şablonunu belirtin.';it = 'Specifica il numero di cartellini prezzo, e un template dell''etichetta.';de = 'Geben Sie die Anzahl der Preisschilder und eine Etikettenvorlage an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND    ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND    ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of labels, and a price tag template.'; ru = 'Укажите количество этикеток и шаблон ценников.';pl = 'Należy wybrać liczbę etykiet i szablonów cenników.';es_ES = 'Especifique la cantidad de etiquetas y el modelo de la etiqueta de precio.';es_CO = 'Especifique la cantidad de etiquetas y el modelo de la etiqueta de precio.';tr = 'Etiket sayısını ve fiyat etiketi şablonunu belirtin.';it = 'Specifica il numero di etichette, e un template del cartellino prezzo.';de = 'Geben Sie die Anzahl der Etiketten und eine Preisschild-Vorlage an.'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
		ElsIf Mode = "LabelsPrinting" Then
			
			If CurrentData.LabelsQuantity = 0 Then
			
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of labels.'; ru = 'Укажите количество этикеток.';pl = 'Należy wybrać liczbę etykiet.';es_ES = 'Especifique la cantidad de etiquetas.';es_CO = 'Especifique la cantidad de etiquetas.';tr = 'Etiket sayısını belirtin.';it = 'Specifica il numero di etichette.';de = 'Geben Sie die Anzahl der Etiketten an.'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
			If Not ValueIsFilled(CurrentData.LabelTemplate) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify a label template.'; ru = 'Укажите шаблон этикетки.';pl = 'Należy wybrać szablon etykiety.';es_ES = 'Especifique el modelo de la etiqueta.';es_CO = 'Especifique el modelo de la etiqueta.';tr = 'Bir etiket şablonu belirtin.';it = 'Specifica un template etichetta.';de = 'Geben Sie eine Etikettenvorlage an.'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
		ElsIf Mode = "TagsPrinting" Then
			
			If CurrentData.PriceTagsQuantity = 0 Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify the number of price tags.'; ru = 'Укажите количество ценников.';pl = 'Należy wybrać liczbę cenników.';es_ES = 'Especifique la cantidad de las etiquetas de precio.';es_CO = 'Especifique la cantidad de las etiquetas de precio.';tr = 'Fiyat etiketi sayısını belirtin.';it = 'Specifica il numero di cartellini di prezzo.';de = 'Geben Sie die Anzahl der Preisschilder an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
			If Not ValueIsFilled(CurrentData.PriceTagsTemplate) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en = 'Specify a price tag template.'; ru = 'Укажите шаблон ценника.';pl = 'Należy wybrać szablon cennika.';es_ES = 'Especifique el modelo de la etiqueta de precio.';es_CO = 'Especifique el modelo de la etiqueta de precio.';tr = 'Bir fiyat etiketi şablonu belirtin.';it = 'Specifica il template del cartellino di prezzo.';de = 'Geben Sie eine Preisschild-Vorlage an.'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the SetPriceTagsQuantity command.
//
&AtClient
Procedure SetPriceTagsQuantity(Command)
	
	ValueSelected = Undefined;
	ShowInputNumber(New NotifyDescription("SetPriceTagsQuantityEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, NStr("en = 'Enter price tag quantity'; ru = 'Введите количество ценников';pl = 'Wprowadź ilość cenników';es_ES = 'Introducir la cantidad de etiquetas de precio';es_CO = 'Introducir la cantidad de etiquetas de precio';tr = 'Fiyat etiketi miktarını girin';it = 'Inserisci quantità prezzo tag';de = 'Geben Sie die Preisschildmenge ein'"), 10, 2);
	
EndProcedure

&AtClient
Procedure SetPriceTagsQuantityEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber In RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.PriceTagsQuantity  = ValueSelected;
            TSRow.Selected              = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en = '%Quantity% price tags are set.'; ru = 'Установлено количество ценников %Quantity%.';pl = '%Quantity% ustawiono ilości cenników.';es_ES = '%Quantity% etiquetas de precio está establecida.';es_CO = '%Quantity% etiquetas de precio está establecida.';tr = '%Quantity% fiyat etiketi belirlendi.';it = '%Quantity% etichette di prezzo sono impostate.';de = '%Quantity% Preisschilder sind gesetzt.'");
        Text = StrReplace(Text, "%Quantity%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure

// Procedure - handler of the SetLabelsQuantity command.
//
&AtClient
Procedure SetLabelsQuantity(Command)
	
	ValueSelected = Undefined;
	ShowInputNumber(New NotifyDescription("SetLabelsQuantityEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, "Input quantity", 10, 2);
	
EndProcedure

&AtClient
Procedure SetLabelsQuantityEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber In RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.LabelsQuantity  = ValueSelected;
            TSRow.Selected              = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en = '%Quantity% labels are set.'; ru = 'Установлено количество этикеток %Quantity%.';pl = '%Quantity% etykiety są ustawione.';es_ES = '%Quantity% etiquetas está establecida.';es_CO = '%Quantity% etiquetas está establecida.';tr = '%Quantity% etiketleri belirlendi.';it = '%Quantity% etichette sono impostate.';de = '%Quantity% Etiketten sind gesetzt.'");
        Text = StrReplace(Text, "%Quantity%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure

// Procedure - handler of the SetPriceTagsTemplate command.
//
&AtClient
Procedure SetPriceTagsTemplate(Command)
	
	ValueSelected = Undefined;
	ShowInputValue(New NotifyDescription("SetPriceTagsTemplateEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, "Choosing the price tag template", Type("CatalogRef.LabelsAndTagsTemplates"));
	
EndProcedure

&AtClient
Procedure SetPriceTagsTemplateEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber In RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.PriceTagsTemplate  = ValueSelected;
            TSRow.Selected         = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en = 'The %Template% template set.'; ru = 'Установлен шаблон ""%Template%"".';pl = 'Szablon zestawu %Template% ustawiony.';es_ES = 'El conjunto de modelos %Template%.';es_CO = 'El conjunto de modelos %Template%.';tr = '%Template% şablonu ayarlandı.';it = 'Impostare il template %Template%.';de = 'Die %Template% Vorlage eingestellt.'");
        Text = StrReplace(Text, "%Template%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure

// Procedure - handler of the SetLabelsTemplate command.
//
&AtClient
Procedure SetLabelsTemplate(Command)
	
	ValueSelected = Undefined;
	ShowInputValue(New NotifyDescription("SetLabelsTemplateEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, "Choosing label template", Type("CatalogRef.LabelsAndTagsTemplates"));
	
EndProcedure

&AtClient
Procedure SetLabelsTemplateEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber In RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.LabelTemplate = ValueSelected;
            TSRow.Selected         = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en = 'The %Template% template set.'; ru = 'Установлен шаблон ""%Template%"".';pl = 'Szablon zestawu %Template% ustawiony.';es_ES = 'El conjunto de modelos %Template%.';es_CO = 'El conjunto de modelos %Template%.';tr = '%Template% şablonu ayarlandı.';it = 'Impostare il template %Template%.';de = 'Die %Template% Vorlage eingestellt.'");
        Text = StrReplace(Text, "%Template%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

#Region Printing

// Procedure sets items visible according to form parameters setting
//
&AtServer
Procedure RefreshElementsVisible()
	
	TagVisible = False;
	PriceTagVisible  = False;
		
	If Mode = "TagsAndLabePrinting" Then
		TagVisible = True;
		PriceTagVisible  = True;
	ElsIf Mode = "TagsPrinting" Then
		TagVisible = False;
		PriceTagVisible  = True;
	ElsIf Mode = "LabelsPrinting" Then
		TagVisible = True;
		PriceTagVisible  = False;
	EndIf;
	
	If PrintFromDocument Then
		Items.FillLabelsQuantityOnInventory.Visible = False;
		Items.FillingModeTagsRadioButton.Visible = TagVisible;
	Else
		Items.FillLabelsQuantityOnInventory.Visible = TagVisible;
		Items.FillingModeTagsRadioButton.Visible = False;
	EndIf;
	
	Items.InventoryTagsNumber.Visible               = TagVisible;
	Items.InventoryTagTemplate.Visible                   = TagVisible;
	Items.InventorySetLabelsTemplate.Visible         = TagVisible;
	Items.InventorySetLabelsNumber.Visible     = TagVisible;
	
	If PrintFromDocument Then
		Items.FillPriceTagsQuantityOnInventory.Visible = False;
		Items.FillingModePriceLabelRadioButton.Visible = PriceTagVisible;
	Else
		Items.FillPriceTagsQuantityOnInventory.Visible = PriceTagVisible;
		Items.FillingModePriceLabelRadioButton.Visible = False;
	EndIf;
	
	Items.InventoryPriceTagsNumber.Visible               = PriceTagVisible;
	Items.InventoryPriceTagTemplate.Visible                    = PriceTagVisible;
	Items.InventorySetPriceTagsTemplate.Visible         = PriceTagVisible;
	Items.InventorySetToStickersNumber.Visible     = PriceTagVisible;
	
	For Each CurRow In Object.Inventory Do
		CurRow.Selected = CheckProductChoicePossibility(CurRow, Mode);
	EndDo;
	
EndProcedure

// Procedure sets the PriceTagsPrinting mode on the server.
//
&AtServer
Procedure SetModeTagsPrintingAtServer()
	
	Mode = "TagsPrinting";
	RefreshElementsVisible();
	
EndProcedure

// Procedure - handler of the SetPriceTagsPrintingMode command.
//
&AtClient
Procedure SetModeTagsPrinting(Command)
	
	SetModeTagsPrintingAtServer();
	
EndProcedure

// Procedure sets the PriceTagsAndLabelsPrinting mode on the server.
//
&AtServer
Procedure SetModeTagsPrintingAndLabelsAtServer()
	
	Mode = "TagsAndLabePrinting";
	RefreshElementsVisible();
	
EndProcedure

// Procedure - handler of the SetPriceTagsAndLabelsPrintingMode command.
//
&AtClient
Procedure SetModeTagsAndLabelsPrinting(Command)
	
	SetModeTagsPrintingAndLabelsAtServer();
	
EndProcedure

// Procedure sets the LabelsPrinting mode on the server.
//
&AtServer
Procedure SetModeLabelsPrintingAtServer()
	
	AutoTitle = False;
	Mode = "LabelsPrinting";
	
	If PrintFromDocument Then
		Title = Nstr("en = 'Labels printing from document'; ru = 'Печать этикеток из документа';pl = 'Drukowanie etykiet z dokumentu';es_ES = 'Impresión de etiquetas desde el documento';es_CO = 'Impresión de etiquetas desde el documento';tr = 'Dokümandan yazdırılan etiketler';it = 'Stampa di etichette dal documento';de = 'Drucken von Etiketten aus dem Dokument'");
	Else
		Title = Nstr("en = 'Labels printing'; ru = 'Печать этикеток';pl = 'Druk etykiet';es_ES = 'Impresión de etiquetas';es_CO = 'Impresión de etiquetas';tr = 'Etiketlerin basımı';it = 'la stampa di etichette';de = 'Etiketten drucken'");
	EndIf;
	
	RefreshElementsVisible();
	
EndProcedure

// Procedure - handler of the SetLabelsPrintingMode command.
//
&AtClient
Procedure SetModeLabelsPrinting(Command)
	
	SetModeLabelsPrintingAtServer();
	
EndProcedure

// Procedure sets the selected print mode
//
// Parameters
//  <Parameter1>  - <Type.Kind> - <parameter
//                 description> <parameter description
//  continuation> <Parameter2>  - <Type.Kind> - <parameter
//                 description> <parameter description continuation>
//
&AtServer
Procedure SetMode(RegimeParameter)
	
	If RegimeParameter = "TagsAndLabePrinting" Then
		SetModeTagsPrintingAndLabelsAtServer();
	ElsIf RegimeParameter = "TagsPrinting" Then
		SetModeTagsPrintingAtServer();
	ElsIf RegimeParameter = "LabelsPrinting" Then
		SetModeLabelsPrintingAtServer();
	Else
		Raise NStr("en = 'Set print mode is not supported'; ru = 'Установленный режим печати не поддерживается';pl = 'Ustalony tryb wydruku nie podtrzymuje się';es_ES = 'No se admite establecer el modo de impresión';es_CO = 'No se admite establecer el modo de impresión';tr = 'Yazdırma modunu ayarlama desteklenmiyor';it = 'Impostare la modalità di stampa non è supportata';de = 'Druckmodus einstellen wird nicht unterstützt'");
	EndIf;
	
EndProcedure

&AtClient
Procedure FillingModePriceLabelRadioButtonOnChange(Item)
	
	If FillingModePriceLabelRadioButton = "Fill in with balances" Then
		FillPriceTagsQuantityOnInventory = True;
		FillOutPriceTagsQuantityOnDocument = False;
	ElsIf FillingModePriceLabelRadioButton = "Fill out from document" Then
		FillPriceTagsQuantityOnInventory = False;
		FillOutPriceTagsQuantityOnDocument = True;
	Else
		FillPriceTagsQuantityOnInventory = False;
		FillOutPriceTagsQuantityOnDocument = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillingModeTagsRadioButtonOnChange(Item)
	
	If FillingModeTagsRadioButton = "Fill in with balances" Then
		FillLabelsQuantityOnInventory = True;
		FillLabelsQuantityByDocument = False;
	ElsIf FillingModeTagsRadioButton = "Fill out from document" Then
		FillLabelsQuantityOnInventory = False;
		FillLabelsQuantityByDocument = True;
	Else
		FillLabelsQuantityOnInventory = False;
		FillLabelsQuantityByDocument = False;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
