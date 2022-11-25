
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("BundleProduct", BundleProduct) Or Not ValueIsFilled(BundleProduct) Then
		Cancel = True;
		Return;
	EndIf;
	
	NewBundleProduct = BundleProduct;
	
	SetFormConditionalAppearance();
	
	OldCount = 0;
	Parameters.Property("Quantity", OldCount);
	If Not ValueIsFilled(OldCount) Then
		OldCount = 1;
	EndIf;
	QuantityBeforeChanging = OldCount;
	Quantity = OldCount;
	
	AttributesValues = Common.ObjectAttributesValues(BundleProduct, "ProductsType, BundlePricingStrategy, UseCharacteristics");
	FillPropertyValues(ThisObject, AttributesValues);
	
	If Parameters.Property("UseCharacteristics") And UseCharacteristics <> Parameters.UseCharacteristics Then
		
		CommonClientServer.MessageToUser(NStr("en = 'After you change characteristics using, you must save the item card'; ru = 'После изменения вариантов требуется сохранение карточки позиции';pl = 'Po zmianie używanych charakterystyk, musisz zapisać kartę pozycji';es_ES = 'Después de cambiar las características usando, debe guardar la ficha del artículo';es_CO = 'Después de cambiar las características usando, debe guardar la ficha del artículo';tr = 'Kullanılan özellikleri değiştirdikten sonra, öğe kartını kaydetmeniz gerekir';it = 'Dopo le modifiche all''utilizzo delle caratteristiche, è necessario salvare la scheda elemento';de = 'Nachdem Sie die Verwendung von Merkmalen geändert haben, müssen Sie die Positionskarte speichern'"));
		Cancel = True;
		Return;
		
	EndIf;
	
	If Parameters.Property("BundlePricingStrategy") Then
		
		BundlePricingStrategy = Parameters.BundlePricingStrategy;
		
	EndIf;
	
	CheckDifferentVAT = (Common.ObjectAttributeValue(BundleProduct, "BundleDisplayInPrintForms")
							= Enums.ProductBundleDisplay.Bundle);
	
	ParametersArray = New Array;
	ParametersArray.Add(New ChoiceParameter("Filter.IsBundle", False));
	TypesArray = New Array;
	
	If ProductsType = Enums.ProductsTypes.InventoryItem Then
		
		TypesArray.Add(Enums.ProductsTypes.InventoryItem);
		TypesArray.Add(Enums.ProductsTypes.Service);
		
	Else
		
		Cancel = True;
		Return;
		
	EndIf;
	
	ParametersArray.Add(New ChoiceParameter("Filter.ProductsType", New FixedArray(TypesArray)));
	Items.BundleComponentsProduct.ChoiceParameters = New FixedArray(ParametersArray);
	
	If Parameters.Property("BundlesComponents") Then
		
		Parameters.Property("BundleCharacteristic", CurrentCharacteristic);
		NewBundleCharacteristic = CurrentCharacteristic;
		
		For Each StructureItem In Parameters.BundlesComponents Do
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Products", StructureItem.Products);
			SearchStructure.Insert("Characteristic", StructureItem.Characteristic);
			
			If StructureItem.Property("MeasurementUnit") Then
				SearchStructure.Insert("MeasurementUnit", StructureItem.MeasurementUnit);
			EndIf;
			
			ComponentsRows = BundleComponents.FindRows(SearchStructure);
			
			If ComponentsRows.Count() = 0 Then
				
				ComponentsRow = BundleComponents.Add();
				DataStructure = New Structure;
				FillPropertyValues(ComponentsRow, StructureItem);
				DataStructure.Insert("Products", ComponentsRow.Products);
				DataStructure = GetProductAttributesOnChange(DataStructure);
				FillPropertyValues(ComponentsRow, DataStructure);
				ComponentsRow.BundleCharacteristic = CurrentCharacteristic;
				
			Else
				
				ComponentsRow = ComponentsRows[0];
				ComponentsRow.Quantity = ComponentsRow.Quantity + StructureItem.Quantity;
				ComponentsRow.CostShare = ComponentsRow.CostShare + StructureItem.CostShare;
				
			EndIf;
			
			If StructureItem.Property("Active") And (StructureItem.Active = True) Then
				Items.BundleComponents.CurrentRow = ComponentsRow.GetID();
			EndIf;
			
		EndDo;
		
		Items.BundleComponentsMeasurementUnit.Visible = False;
		For Each Str In BundleComponents Do
			
			If ValueIsFilled(Str.MeasurementUnit) Then
				Items.BundleComponentsMeasurementUnit.Visible = True;
				Break;
			EndIf;
			
		EndDo;
		
	ElsIf Parameters.Property("ChoiceMode") And Parameters.ChoiceMode Then
		
		ChoiceMode = Parameters.ChoiceMode;
		FillBundleComponents();
		CurrentCharacteristic = Catalogs.ProductsCharacteristics.EmptyRef();
		RefreshRowFilter(BundleComponents, CurrentCharacteristic);
		FilterStructure = New Structure;
		FilterStructure.Insert("Show", True);
		Items.BundleComponents.RowFilter = New FixedStructure(FilterStructure);
		
	Else
		
		SaveChanges = True;
		ReadData();
		
	EndIf;
	
	If Not SaveChanges And Not ChoiceMode Then
		
		ChangingItems = StringFunctionsClientServer.SplitStringIntoSubstringsArray("BundleComponentsProduct, BundleComponentsCharacteristic, BundleComponentsMeasurementUnit");
		
		For Each ChangingItem In ChangingItems Do
			CommonClientServer.SetFormItemProperty(Items, ChangingItem, "WarningOnEdit", WarningOnComponentsEdit());
		EndDo;
		
	EndIf;
	
	Title = BundleProduct.Description;
		
	FormManagement(ThisObject);
	
	If SaveChanges Then
		WindowPositionSavingKey = "InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle/SaveChangesMode";
	ElsIf ChoiceMode Then
		WindowPositionSavingKey = "InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle/ChoiseMode";
	Else
		WindowPositionSavingKey = "InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle/ComponentsChangingMode";
	EndIf;
	
	If SaveChanges Then
		
		Items.CharacteristicsPresentation.ToolTip =
			NStr("en = 'There are two predefined items:
				| - Without variant: components from this item will be used for document without products variants
				| - Common bundle components for all variants: components from this item will be added for all variants'; 
				|ru = 'Имеется две предопределенные позиции:
				| - Без варианта: компоненты данной позиции используются в документе без вариантов номенклатуры
				| - Общие компоненты набора для всех вариантов: компоненты данной позиции добавляются для всех вариантов';
				|pl = 'Istnieje dwie predefiniowane pozycji:
				| - Bez wariantu: komponenty z tej pozycji będą używane dla dokumentu bez wariantów produktów
				| - Wspólne komponenty zestawu dla wszystkich wariantów: komponenty z tej pozycji będą dodane dla wszystkich wariantów';
				|es_ES = 'Hay dos elementos predefinidos:
				| - Sin variante: los componentes de este artículo se utilizarán para documentos sin variantes de productos
				| - Componentes de paquete comunes para todas las variantes: los componentes de este artículo se agregarán para todas las variantes';
				|es_CO = 'Hay dos elementos predefinidos:
				| - Sin variante: los componentes de este artículo se utilizarán para documentos sin variantes de productos
				| - Componentes de paquete comunes para todas las variantes: los componentes de este artículo se agregarán para todas las variantes';
				|tr = 'Öntanımlı iki öğe vardır:
				| - Varyantsız: Bu öğenin malzemeleri ürün varyantsız belgeler için kullanılır
				| - Tüm varyantlar için ortak ürün seti malzemeleri: Bu öğenin malzemeleri tüm varyantlar için eklenir';
				|it = 'Ci sono due elementi predefiniti:
				|- Senza variante: componenti da questo elemento saranno utilizzate per documenti senza varianti di articoli
				| - Componenti di aggregato comuni per tutte le varianti: le componenti da questo elemento saranno aggiunte a tutte le varianti';
				|de = 'Es gibt zwei vordefinierte Elemente:
				| - Ohne Variante: Komponenten aus diesem Element wird für Dokumente ohne Produktvarianten verwendet
				| - Gemeinsame Komponenten der Artikelgruppe für alle Varianten: Komponenten aus diesem Element wird für alle Varianten hinzugefügt'");
		
	EndIf;
	
	// Characteristics
	If Not ThisObject.SaveChanges Then
		RefreshConditionalAppearanceForCharacteristicsTable(ThisObject);
		FillUseCharacteristicAttributes()
	EndIf;
	// End Characteristics
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AddCharacteristic" And Source=BundleProduct And Items.Characteristics.Visible Then
		
		If TypeOf(Parameter) = Type("CatalogRef.ProductsCharacteristics") 
			And ValueIsFilled(Parameter) 
			And Characteristics.FindByValue(Parameter) = Undefined Then
			Characteristics.Add(Parameter, String(Parameter));
		EndIf;
		
	ElsIf EventName = "BundleComponentsCopy" And Parameter = BundleProduct Then
		
		ReadData();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If Modified And Not ReadOnly Then
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		Text = NStr("en='Save changes?'; ru = 'Сохранить изменения?';pl = 'Zapisać zmiany?';es_ES = '¿Guardar los cambios?';es_CO = '¿Guardar los cambios?';tr = 'Değişiklikler kaydedilsin mi?';it = 'Salvare le modifiche?';de = 'Änderungen speichern?'");
		ShowQueryBox(NotifyDescription, Text, QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		SaveChanges();
		Close(True);
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure QuantityOnChange(Item)
	
	If Quantity = QuantityBeforeChanging Then
		Return;
	EndIf;
	
	FillBundleProductInRows();
	
	If Quantity < QuantityBeforeChanging Then
		BundlesClientServer.DeleteBundleComponent(NewBundleProduct, NewBundleCharacteristic, BundleComponents, QuantityBeforeChanging, Quantity);
	Else
		BundlesClientServer.AddBundleComponent(NewBundleProduct, NewBundleCharacteristic, BundleComponents, QuantityBeforeChanging, Quantity);
	EndIf;
	
	QuantityBeforeChanging = Quantity;
	
	Modified = True;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure NewBundleProductOnChange(Item)
	
	ReplaceComponents();
	
EndProcedure

&AtClient
Procedure NewBundleCharacteristicAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = BundleCharacteristic(NewBundleProduct, Text);
	
EndProcedure

&AtClient
Procedure NewBundleCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenStructure = New Structure;
	OpenStructure.Insert("BundleProduct", NewBundleProduct);
	OpenStructure.Insert("ChoiceMode", True);
	OpenStructure.Insert("CloseOnChoice", True);
	OpenForm("InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle", OpenStructure, Item, , , , , FormWindowOpeningMode.LockOwnerWindow); 
	
EndProcedure

&AtClient
Procedure NewBundleCharacteristicOnChange(Item)
	
	ReplaceComponents();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure CharacteristicsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
	If Clone And (Item.CurrentData = Undefined Or Not ValueIsFilled(Item.CurrentData.Value)) Then
		Return;
	EndIf;
	
	OpenStructure = New Structure;
	
	If Clone Then
		OpenStructure.Insert("CloneValue", Item.CurrentData.Value);
	Else
		FilterStructure = New Structure;
		FilterStructure.Insert("Owner", BundleProduct);
		OpenStructure.Insert("FillingValue", FilterStructure);
	EndIf;
	
	OpenForm("Catalog.ProductsCharacteristics.ObjectForm", OpenStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure CharacteristicsOnActivateRow(Item)
	
	If Not SaveChanges And Not ChoiceMode Then
		Return;
	EndIf; 
	
	ListCurrentItem = Item.CurrentData;
	If ListCurrentItem.Value <> CurrentCharacteristic Then
		CurrentCharacteristic = ListCurrentItem.Value;
		RefreshRowFilter(BundleComponents, CurrentCharacteristic);
		FilterStructure = New Structure;
		FilterStructure.Insert("Show", True);
		Items.BundleComponents.RowFilter = New FixedStructure(FilterStructure);
	EndIf;
	
EndProcedure

&AtClient
Procedure CharacteristicsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If ChoiceMode Then
		TableLine = Item.CurrentData;
		NotifyChoice(TableLine.Value);
	EndIf;

EndProcedure

&AtClient
Procedure BundleComponentsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Not SaveChanges And Not ChoiceMode And Quantity > 1 Then
		// On product of bundle changing count becomes 1
		Cancel = True;
		BeforeComponentsChanging();
	EndIf;
	
EndProcedure

&AtClient
Procedure BundleComponentsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		TableLine = Item.CurrentData;
		TableLine.BundleCharacteristic = ?(SaveChanges, CurrentCharacteristic, NewBundleCharacteristic);
		TableLine.Show = True;
		TableLine.IsCommon = (SaveChanges And CurrentCharacteristic=Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure BundleComponentsOnEditEnd(Item, NewRow, CancelEdit)
	
	If Not CancelEdit And SaveChanges And CurrentCharacteristic=Undefined And NewRow Then
		
		// Offset of the common rows to beginning
		TableLine = Item.CurrentData;
		LineIndex = BundleComponents.IndexOf(TableLine);
		FilterStructure = New Structure;
		FilterStructure.Insert("IsCommon", True);
		CommonRows = BundleComponents.FindRows(FilterStructure);
		
		If (CommonRows.Count() = 1) And (LineIndex > 0) Then
			
			BundleComponents.Move(LineIndex, -LineIndex);
			
		ElsIf CommonRows.Count()>1 Then
			
			Offset = LineIndex - BundleComponents.IndexOf(CommonRows[CommonRows.Count() - 2]) - 1;
			
			If Offset > 0 Then
				BundleComponents.Move(LineIndex, -Offset);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BundleComponentsOnChange(Item)
	
	OnComponentsChanging();
	
EndProcedure

&AtClient
Procedure BundleComponentsBeforeDeleteRow(Item, Cancel)
	
	If SaveChanges And ValueIsFilled(CurrentCharacteristic) Then
		
		For Each RowID In Item.SelectedRows Do
			
			Row = BundleComponents.FindByID(RowID);
			
			If Row.IsCommon Then
				Cancel = True;
				Return;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BundleComponentsAfterDeleteRow(Item)
	
	OnComponentsChanging();
	
EndProcedure

&AtClient
Procedure OnComponentsChanging()
	
	Modified = True;
	
	Items.NewBundleProduct.WarningOnEditRepresentation = WarningOnEditRepresentation.Show;
	Items.NewBundleCharacteristic.WarningOnEditRepresentation = WarningOnEditRepresentation.Show;
	
EndProcedure

&AtClient
Procedure BundleComponentsProductChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not SaveChanges And Not ChoiceMode And Quantity > 1 Then
		
		RowID = Items.BundleComponents.CurrentRow;
		// On product of bundle changing count becomes 1
		ResetComponentsCount();
		CurrentRow = BundleComponents.FindByID(RowID);
		
		If CurrentRow <> Undefined Then
			
			CurrentRow.Products = SelectedValue;
			OnBundlesComponentsChanging(RowID);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BundleComponentsProductOnChange(Item)
	
	OnBundlesComponentsChanging();
	
EndProcedure

&AtClient
Procedure OnBundlesComponentsChanging(RowID = Undefined)
	
	If RowID=Undefined Then
		TableLine = Items.BundleComponents.CurrentData;
	Else
		TableLine = BundleComponents.FindByID(RowID);
	EndIf;
	
	DataStructure = New Structure;
	DataStructure.Insert("Products", TableLine.Products);
	DataStructure = GetProductAttributesOnChange(DataStructure);
	
	FillPropertyValues(TableLine, DataStructure);
	TableLine.Quantity = 1;
	TableLine.CostShare = 1;
	
	If DataStructure.ProductsType <> PredefinedValue("Enum.ProductsTypes.Work") Then
		TableLine.FixedCost = True;
	EndIf;
	
	// Characteristics
	If Not ThisObject.SaveChanges Then
		FillUseCharacteristicAttributes()
	EndIf;
	// End Characteristics
	
EndProcedure

&AtClient
Procedure BundleComponentsCharacteristicChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not SaveChanges And Not ChoiceMode And Quantity > 1 Then
		
		RowID = Items.BundleComponents.CurrentRow;
		// On product of bundle changing count becomes 1
		ResetComponentsCount();
		CurrentRow = BundleComponents.FindByID(RowID);
		
		If CurrentRow <> Undefined Then
			CurrentRow.Characteristic = SelectedValue;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BundleComponentsMeasurementUnitChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not SaveChanges And Not ChoiceMode And Quantity > 1 Then
		
		RowID = Items.BundleComponents.CurrentRow;
		// On product of bundle changing count becomes 1
		ResetComponentsCount();
		CurrentRow = BundleComponents.FindByID(RowID);
		If CurrentRow<>Undefined Then
			CurrentRow.MeasurementUnit = SelectedValue;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Cancel = False;
	
	If Not SaveChanges And Not ChoiceMode And BundleComponents.Count() = 0 Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Bundle components required'; ru = 'Не заполнено поле ""Компоненты набора""';pl = 'Wymagany jest zestaw komponentów';es_ES = 'Se requieren componentes del paquete';es_CO = 'Se requieren componentes del paquete';tr = 'Ürün seti malzemeleri gerekli';it = 'Richieste le componenti di aggregato';de = 'Komponenten der Artikelgruppe benötigt'"),,
			"BundleComponents", ,
			Cancel);
		
	EndIf;
	
	FirstVAT = Undefined;
	If CheckDifferentVAT And BundleComponents.Count() Then
		FirstVAT = BundleComponents[0].VATRate;
	EndIf;
	
	For Each TableLine In BundleComponents Do
		
		If Not ValueIsFilled(TableLine.Products) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Product not filled'; ru = 'Не заполнено поле ""Номенклатура""';pl = 'Produkt nie jest wypełniony';es_ES = 'Producto no rellenado';es_CO = 'Producto no rellenado';tr = 'Ürün doldurulmadı';it = 'Articolo non compilato';de = 'Produkt nicht aufgefüllt'"),,
				"BundleComponents[" + BundleComponents.IndexOf(TableLine) + "].Products", ,
				Cancel);
		EndIf;
			
		If Not ValueIsFilled(TableLine.Quantity) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Quantity not filled'; ru = 'Не заполнено поле ""Количество""';pl = 'Ilość nie jest wypełniona';es_ES = 'Cantidad no rellenada';es_CO = 'Cantidad no rellenada';tr = 'Miktar doldurulmadı';it = 'Quantità non compilata';de = 'Menge nicht aufgefüllt'"),,
				"BundleComponents[" + BundleComponents.IndexOf(TableLine) + "].Quantity", ,
				Cancel);
		EndIf;
		
		If Items.BundleComponentsMeasurementUnit.Visible And Not ValueIsFilled(TableLine.MeasurementUnit) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Measurement unit not filled'; ru = 'Не заполнено поле ""Единица измерения""';pl = 'Jednostka miary nie jest wypełniona';es_ES = 'Unidad de medida vacía';es_CO = 'Unidad de medida vacía';tr = 'Ölçü birimi doldurulmadı';it = 'Unità di misura non compilata';de = 'Maßeinheit nicht aufgefüllt'"),,
				"BundleComponents[" + BundleComponents.IndexOf(TableLine) + "].MeasurementUnit", ,
				Cancel);
		EndIf;
		
		If CheckDifferentVAT And (FirstVAT <> TableLine.VATRate) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Products have different VAT rates and the print method for this bundle is specified as Bundle.
							|It means that it will be displayed on print forms as one line, which can have only one VAT rate.
							|You can either select components with the same VAT rate, or change the print method of this bundle.'; 
							|ru = 'Компоненты набора имеют разные ставки НДС, а метод печати для этого комплекта определен как Набор.
							|Это означает, что он будет отображаться в печатных формах в одну строку, которая может иметь только одну ставку НДС.
							|Выберите компоненты с одинаковой ставкой НДС или измените способ печати для этого набора.';
							|pl = 'Produkty mają różne stawki VAT i formularz wydruku dla tego zestawu jest określony jako Zestaw.
							|To znaczy, że on będzie wyświetlany w formularzach wydruku jako jeden wiersz, który może mieć tylko jedną stawkę VAT.
							|Możesz wybrać komponenty z taką samą stawką VAT lub zmienić sposób wydruku tego zestawu.';
							|es_ES = 'Los productos tienen diferentes tasas del IVA y el método de impresión para este paquete se especifica como Paquete.
							|Significa que se mostrará en los formularios impresos como una línea, que solo puede tener una tasa de IVA.
							|Puede seleccionar componentes con la misma tasa del IVA, o cambie el método de impresión de este paquete.';
							|es_CO = 'Los productos tienen diferentes tasas del IVA y el método de impresión para este paquete se especifica como Paquete.
							|Significa que se mostrará en los formularios impresos como una línea, que solo puede tener una tasa de IVA.
							|Puede seleccionar componentes con la misma tasa del IVA, o cambie el método de impresión de este paquete.';
							|tr = 'Ürünler farklı KDV oranlarına sahip ve bu ürün seti için yazdırma yöntemi Ürün seti olarak belirtilmiş.
							|Başka bir deyişle, yazdırma formlarında tek bir KDV oranına sahip tek satır olarak gösterilecek.
							|Aynı KDV oranına sahip malzemeler seçebilir veya bu ürün setinin yazdırma yöntemini değiştirebilirsiniz.';
							|it = 'Gli articoli hanno diverse aliquote IVA e il metodo di stampa per questo aggregato è indicato come Aggregato.
							|Ciò significa che sarà mostrato sui moduli di stampa come una riga che può avere una sola aliquota IVA.
							|È possibile sia selezionare le componenti con la medesima aliquota IVA, sia modificare il metodo di stampa di questo aggregato.';
							|de = 'Produkte haben unterschiedliche USt-Sätze und die Druckmethode für diese Artikelgruppe wird als Artikelgruppe angegeben.
							|Das heißt, dass sie auf Druckformularen als eine Zeile angezeigt wird, die nur einen USt.-Satz haben kann
							|Sie können entweder Komponenten mit dem gleichen USt.-Satz auswählen oder die Druckmethode dieser Artikelgruppe ändern.'"),,
				"BundleComponents[" + BundleComponents.IndexOf(TableLine) + "].Products", ,
				Cancel);
		EndIf;
		
	EndDo;
	
	If Cancel Then
		Return;
	EndIf;
	
	If ChoiceMode Then
		
		TableLine = Items.Characteristics.CurrentData;
		If TableLine=Undefined Then
			Return;
		EndIf;
		NotifyChoice(TableLine.Value);
		
	Else
		
		SaveChanges();
		Close(True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveUp(Command)

	MoveTableLine(-1);
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	MoveTableLine(1);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFormConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "BundleComponents.IsCommon", True);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "CurrentCharacteristic", Undefined, DataCompositionComparisonType.NotEqual);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "BundleComponents");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.UnavailableTabularSectionTextColor);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "Characteristics.Check", True);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "Characteristics");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font(Items.Characteristics.Font, , , True));
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	
	CommonClientServer.SetFormItemProperty(Items, "GroupCharacteristics",		"Visible",
		(Form.SaveChanges Or Form.ChoiceMode) And Form.UseCharacteristics);
	CommonClientServer.SetFormItemProperty(Items, "BundleComponentsCostShare",	"Visible",
		(Form.BundlePricingStrategy = PredefinedValue("Enum.ProductBundlePricingStrategy.BundlePriceProratedByComponentsCost")));
	CommonClientServer.SetFormItemProperty(Items, "GroupCountComponents",		"Visible",
		Not Form.SaveChanges And Not Form.ChoiceMode);
	CommonClientServer.SetFormItemProperty(Items, "BundleComponents",			"ReadOnly", Form.ChoiceMode);
	CommonClientServer.SetFormItemProperty(Items, "CommandBarCharacteristics",	"Visible", Not Form.ChoiceMode);
	CommonClientServer.SetFormItemProperty(Items, "CommandBarBundleComponents",	"Visible",
		Not Form.ChoiceMode And Form.SaveChanges);
	CommonClientServer.SetFormItemProperty(Items, "BundleComponentsChange",		"Visible", Not Form.ChoiceMode);
	
	// Mode_ChooseCharacteristics
	If Form.ChoiceMode Then
		TitleChoose = NStr("en = 'Choose'; ru = 'Выбор';pl = 'Wybierz';es_ES = 'Elegir';es_CO = 'Elegir';tr = 'Seç';it = 'Selezionare';de = 'Auswählen'");
		If Items.WriteAndClose.Title <> TitleChoose Then
			Items.WriteAndClose.Title = TitleChoose;
		EndIf;
	EndIf;
	// End Mode_ChooseCharacteristics
	
	// Mode_ChangeComponents
	If Not Form.SaveChanges And Not Form.ChoiceMode Then
		
		ChangingItems = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
			"BundleComponentsProduct, BundleComponentsCharacteristic, BundleComponentsMeasurementUnit");
		
		For Each ChangingItem In ChangingItems Do
			If Form.Quantity > 1 Then
				CommonClientServer.SetFormItemProperty(Items, ChangingItem, "WarningOnEditRepresentation", WarningOnEditRepresentation.Show);
			Else
				CommonClientServer.SetFormItemProperty(Items, ChangingItem, "WarningOnEditRepresentation", WarningOnEditRepresentation.DontShow);
			EndIf;
		EndDo;
		
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items, "NewBundleCharacteristic",		"ReadOnly", Not Form.UseCharacteristics); 
	
	If Form.UseCharacteristics Then
		CommonClientServer.SetFormItemProperty(Items, "NewBundleCharacteristic",	"InputHint", "");
	Else
		CommonClientServer.SetFormItemProperty(Items, "NewBundleCharacteristic",	"InputHint", NStr("en = '<Not used>'; ru = '<Не используется>';pl = '<Nie używane>';es_ES = '<No se usa>';es_CO = '<No se usa>';tr = '<Kullanılmıyor>';it = '<Non utilizzato>';de = '<Nicht verwendet>'"));
	EndIf;
	// End Mode_ChangeComponents
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshRowFilter(BundleComponents, CurrentCharacteristic)
	
	For Each Row In BundleComponents Do
		
		If CurrentCharacteristic = Undefined Then
			Show = Row.IsCommon;
		ElsIf CurrentCharacteristic = PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef") Then
			Show = (CurrentCharacteristic = Row.BundleCharacteristic And Not Row.IsCommon);
		Else
			Show = (CurrentCharacteristic = Row.BundleCharacteristic Or Row.IsCommon);
		EndIf;
		
		If Row.Show<>Show Then
			Row.Show = Show;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillBundleComponents()
	
	Characteristics.Clear();
	BundleComponents.Clear();
	
	Query = New Query;
	Query.SetParameter("Products", BundleProduct);
	Query.Text =
	"SELECT
	|	&Products AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	1 AS Order,
	|	"""" AS CharacteristicDescription
	|INTO ProductAndCharacteristic
	|
	|UNION ALL
	|
	|SELECT
	|	&Products,
	|	UNDEFINED,
	|	2,
	|	""""
	|
	|UNION ALL
	|
	|SELECT
	|	ProductsCharacteristics.Owner,
	|	ProductsCharacteristics.Ref,
	|	3,
	|	ProductsCharacteristics.Description
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Owner = &Products
	|
	|UNION ALL
	|
	|SELECT
	|	ProductsCharacteristics.Owner,
	|	ProductsCharacteristics.Ref,
	|	3,
	|	ProductsCharacteristics.Description
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Owner = CAST(&Products AS Catalog.Products).ProductsCategory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductAndCharacteristic.Order AS OrderCharacteristic,
	|	ProductAndCharacteristic.Characteristic AS BundleCharacteristic,
	|	ProductAndCharacteristic.CharacteristicDescription AS CharacteristicDescription,
	|	ISNULL(BundlesComponents.Products, UNDEFINED) AS Products,
	|	ISNULL(BundlesComponents.Characteristic, UNDEFINED) AS Characteristic,
	|	ISNULL(BundlesComponents.MeasurementUnit, UNDEFINED) AS MeasurementUnit,
	|	ISNULL(BundlesComponents.Quantity, 0) AS Quantity,
	|	ISNULL(BundlesComponents.CostShare, 0) AS CostShare,
	|	ISNULL(BundlesComponents.Order, 0) AS Order,
	|	ISNULL(BundlesComponents.IsCommon, FALSE) AS IsCommon
	|FROM
	|	ProductAndCharacteristic AS ProductAndCharacteristic
	|		LEFT JOIN InformationRegister.BundlesComponents AS BundlesComponents
	|		ON ProductAndCharacteristic.Products = BundlesComponents.BundleProduct
	|			AND (ProductAndCharacteristic.Characteristic = BundlesComponents.BundleCharacteristic
	|					AND NOT BundlesComponents.IsCommon
	|				OR ProductAndCharacteristic.Characteristic = UNDEFINED
	|					AND BundlesComponents.IsCommon)
	|
	|ORDER BY
	|	OrderCharacteristic,
	|	CharacteristicDescription,
	|	Order
	|TOTALS
	|	MAX(CharacteristicDescription)
	|BY
	|	OrderCharacteristic,
	|	BundleCharacteristic";
	
	SelectionOrder = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionOrder.Next() Do
		
		SelectionCharacteristics = SelectionOrder.Select(QueryResultIteration.ByGroups);
		
		While SelectionCharacteristics.Next() Do
			
			If SelectionCharacteristics.BundleCharacteristic = Undefined Then
				CharacteristicsDescription = TitleBundlesComponents();
			ElsIf Not ValueIsFilled(SelectionCharacteristics.BundleCharacteristic) Then
				CharacteristicsDescription = TitleWithoutCharacteristics();
			Else
				CharacteristicsDescription = String(SelectionCharacteristics.BundleCharacteristic);
			EndIf;
			
			If Not ChoiceMode Or SelectionCharacteristics.BundleCharacteristic <> Undefined Then
				Characteristics.Add(SelectionCharacteristics.BundleCharacteristic,
					CharacteristicsDescription,
					Not ValueIsFilled(SelectionCharacteristics.BundleCharacteristic));
			EndIf;
			
			Selection = SelectionCharacteristics.Select();
			
			While Selection.Next() Do
				
				If Selection.Products = Undefined Then
					Continue;
				EndIf;
				
				ComponentsRow = BundleComponents.Add();
				FillPropertyValues(ComponentsRow, Selection);
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SaveChangesAtServer()
	
	RecordSet = InformationRegisters.BundlesComponents.CreateRecordSet();
	RecordSet.Filter.BundleProduct.Set(BundleProduct);
	
	For Each Row In BundleComponents Do
		
		Record = RecordSet.Add();
		FillPropertyValues(Record, Row);
		Record.BundleProduct = BundleProduct;
		Record.Order = BundleComponents.IndexOf(Row);
		
	EndDo;
	
	RecordSet.Write(True);
	
EndProcedure

&AtClient
Procedure FillBundleProductInRows()
	
	For Each TableLine In BundleComponents Do
		TableLine.BundleProduct = NewBundleProduct;
	EndDo;
	
EndProcedure

&AtClient
Procedure RollUpDuplicates()
	
	RowsNumber = BundleComponents.Count();
	RowsToDelete = New Array;
	
	For Each Row In BundleComponents Do
		
		If RowsToDelete.Find(Row) <> Undefined Then
			Continue;
		EndIf;
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products", Row.Products);
		SearchStructure.Insert("Characteristic", Row.Characteristic);
		SearchStructure.Insert("MeasurementUnit", Row.MeasurementUnit);
		SearchStructure.Insert("IsCommon", Row.IsCommon);
		SearchStructure.Insert("BundleCharacteristic", Row.BundleCharacteristic);
		
		FoundRows = BundleComponents.FindRows(SearchStructure);
		
		If FoundRows.Count() <= 1 Then
			Continue;
		EndIf;
		
		For Each FoundRow In FoundRows Do
			
			If FoundRow.GetID() = Row.GetID() Then
				Continue;
			EndIf;
			
			Row.Quantity = Row.Quantity + FoundRow.Quantity;
			Row.CostShare = Row.CostShare + FoundRow.CostShare;
			RowsToDelete.Add(FoundRow);
			
		EndDo;
		
	EndDo;
	
	For Each FoundRow In RowsToDelete Do
		BundleComponents.Delete(FoundRow);
	EndDo;
	
EndProcedure
 
&AtServerNoContext
Function GetProductAttributesOnChange(DataStructure)
	
	AttributesValues = Common.ObjectAttributesValues(DataStructure.Products, "MeasurementUnit, UseSerialNumbers, UseCharacteristics, UseBatches, ProductsType, VATRate");
	CommonClientServer.SupplementStructure(DataStructure, AttributesValues, True);
	DataStructure.Insert("ProductsTypeInventory", AttributesValues.ProductsType = Enums.ProductsTypes.InventoryItem);
	DataStructure.Insert("ProductsTypeService", AttributesValues.ProductsType = Enums.ProductsTypes.Service);
	DataStructure.Insert("VATRate", AttributesValues.VATRate);

	Return DataStructure;
	
EndFunction

&AtClient
Procedure SaveChanges()
	
	If SaveChanges Then
		
		RollUpDuplicates();
		
		SaveChangesAtServer();
		
		Notify(BundlesClient.EventNameOfChangingBundleComponents(), , BundleProduct);
		
	Else
		
		ReturnStructure = New Structure;
		ReturnStructure.Insert("BundleProduct", BundleProduct);
		ReturnStructure.Insert("BundleCharacteristic", CurrentCharacteristic);
		ReturnStructure.Insert("Quantity", Quantity);
		ReturnStructure.Insert("BundleComponents", New Array);
		
		For Each Row In BundleComponents Do
			
			RowStructure = New Structure("Products, Characteristic, Quantity, CostShare, MeasurementUnit, ProductsTypeInventory, ProductsTypeService");
			FillPropertyValues(RowStructure, Row);
			RowStructure.Insert("BundleProduct", NewBundleProduct);
			RowStructure.Insert("BundleCharacteristic", NewBundleCharacteristic);
			ReturnStructure.BundleComponents.Add(RowStructure);
			
		EndDo;
		
		AddProductsTypes(ReturnStructure);
		
		Notify(BundlesClient.EventNameOfChangingBundleComponents(),
			ReturnStructure,
			?(TypeOf(FormOwner) = Type("ClientApplicationForm"), FormOwner.UUID, Undefined));
		
	EndIf;
	
	Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure AddProductsTypes(ReturnStructure)

	ProductsArray = New Array;
	
	For Each Item In ReturnStructure.BundleComponents Do
		If ValueIsFilled(Item.Products) And ProductsArray.Find(Item.Products) = Undefined Then
			ProductsArray.Add(Item.Products);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("ProductsArray", ProductsArray);
	Query.Text =
	"SELECT
	|	Products.Ref AS Ref,
	|	Products.ProductsType AS ProductsType,
	|	CASE
	|		WHEN Products.ProductsType = VALUE(Enum.ProductsTypes.Work)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS FixedCost
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.Ref IN(&ProductsArray)";
	
	ProductsTypes = New Map;
	FixedCost = New Map;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ProductsTypes.Insert(Selection.Ref, Selection.ProductsType);
		FixedCost.Insert(Selection.Ref, Selection.FixedCost);
	EndDo;
	
	For Each Item In ReturnStructure.BundleComponents Do
		Item.Insert("ProductsType", ProductsTypes.Get(Item.Products));
		Item.Insert("FixedCost", FixedCost.Get(Item.Products));
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function TitleBundlesComponents()
	
	Return NStr("en = 'Common bundle components for all variants'; ru = 'Общие компоненты набора для всех вариантов';pl = 'Wspólne komponenty zestawu dla wszystkich wariantów';es_ES = 'Componentes de paquete comunes para todas las variantes';es_CO = 'Componentes de paquete comunes para todas las variantes';tr = 'Tüm varyantlar için ortak ürün seti malzemeleri';it = 'Componenti comuni di aggregati per tutte le varianti';de = 'Gemeinsame Komponenten der Artikelgruppe für alle Varianten'");	
	
EndFunction 

&AtClientAtServerNoContext
Function TitleWithoutCharacteristics()
	
	Return NStr("en = 'Without variant'; ru = 'Без варианта';pl = 'Bez wariantu';es_ES = 'Sin variante';es_CO = 'Sin variante';tr = 'Varyantsız';it = 'Senza variante';de = 'Ohne Varianten'");	
	
EndFunction

&AtClient
Procedure BeforeComponentsChanging()
	
	Notification = New NotifyDescription("BeforeComponentsChangingEnd", ThisObject);
	TextEnd = "." + Chars.LF + NStr("en = 'Continue changing?'; ru = 'Продолжить изменение?';pl = 'Kontynuować zmianę?';es_ES = '¿Continuar cambiando?';es_CO = '¿Continuar cambiando?';tr = 'Değiştirmeye devam edilsin mi?';it = 'Continuare le modifiche?';de = 'Weiter ändern?'");
	ShowQueryBox(Notification, WarningOnComponentsEdit() + TextEnd, QuestionDialogMode.OKCancel, , DialogReturnCode.OK);
	
EndProcedure

&AtClient
Procedure BeforeComponentsChangingEnd(Result, Parameters) Export
	
	If Result <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	ResetComponentsCount();
	
EndProcedure

&AtClient
Procedure ResetComponentsCount()
	
	Quantity = 1;
	FillBundleProductInRows();
	BundlesClientServer.DeleteBundleComponent(NewBundleProduct, NewBundleCharacteristic, BundleComponents, QuantityBeforeChanging, Quantity);
	QuantityBeforeChanging = Quantity;
	
	FormManagement(ThisObject);
	
	Modified = True;
	
EndProcedure

&AtClientAtServerNoContext
Function WarningOnComponentsEdit()
	
	Return NStr("en = 'Quantity of bundles will be reset to 1. After changings, you can set quantity again.'; ru = 'Количество наборов будет изменено на 1. После завершения изменений вы можете снова установить количество.';pl = 'Ilość zestawów zostanie zresetowana do 1. Po zmianach będzie można ustawić ilość ponownie.';es_ES = 'La cantidad de paquetes se restablecerá a 1. Después de los cambios, puede volver a fijar la cantidad.';es_CO = 'La cantidad de paquetes se restablecerá a 1. Después de los cambios, puede volver a fijar la cantidad.';tr = 'Ürün setlerinin miktarı 1 olarak ayarlanacak. Değişikliklerden sonra miktarı yeniden ayarlayabilirsiniz.';it = 'La quantità di kit di prodotti sarà reimpostata a 1. Dopo le modifiche, sarà possibile impostare nuovamente la quantità.';de = 'Die Anzahl der Artikelgruppen wird auf 1 zurückgesetzt. Nach Änderungen können Sie die Menge wieder festlegen.'");	
	
EndFunction 

&AtServer
Procedure ReadData()
	
	FillBundleComponents();
	CurrentCharacteristic = Catalogs.ProductsCharacteristics.EmptyRef();
	RefreshRowFilter(BundleComponents, CurrentCharacteristic);
	FilterStructure = New Structure;
	FilterStructure.Insert("Show", True);
	Items.BundleComponents.RowFilter = New FixedStructure(FilterStructure);
	
	// Characteristics
	If Not ThisObject.SaveChanges Then
		FillUseCharacteristicAttributes()
	EndIf;
	// End Characteristics
	
EndProcedure

// Moves selected lines on one line up/down
//
// Parameters:
//  Direction	 - Number [-1;1]:
//                            1  - down,
//                            -1 - up.
//
&AtServer
Procedure MoveTableLine(Direction)
	
	If Items.BundleComponents.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	If Direction > 0 Then
		LastRowID = Items.BundleComponents.SelectedRows[Items.BundleComponents.SelectedRows.UBound()];
	Else
		LastRowID = Items.BundleComponents.SelectedRows[0];
	EndIf;
	
	LastRow = BundleComponents.FindByID(LastRowID);
	
	FilterStructure = New Structure;
	If Not CurrentCharacteristic=Undefined Then
		FilterStructure.Insert("BundleCharacteristic", CurrentCharacteristic);
		FilterStructure.Insert("IsCommon", False);
	Else
		FilterStructure.Insert("IsCommon", True);
	EndIf;
	Rows = BundleComponents.FindRows(FilterStructure);
	
	If Direction > 0 Then
		
		Index = Items.BundleComponents.SelectedRows.UBound();
		While Index >= 0 Do
			
			RowIDRows = Items.BundleComponents.SelectedRows[Index];
			Row = BundleComponents.FindByID(RowIDRows);
			IndexInArray = Rows.Find(Row);
			
			If IndexInArray = Undefined Or (IndexInArray + Direction >= Rows.Count()) Then
				Index = Index - 1;
				Continue;
			EndIf;
			
			LineIndex = BundleComponents.IndexOf(Row);
			DirectionIndex = BundleComponents.IndexOf(Rows[IndexInArray + Direction]);
			BundleComponents.Move(LineIndex, DirectionIndex - LineIndex);
			Index = Index - 1;
			
		EndDo;
		
	Else
		
		For Each RowIDRows In Items.BundleComponents.SelectedRows Do
			
			Row = BundleComponents.FindByID(RowIDRows);
			IndexInArray = Rows.Find(Row);
			
			If IndexInArray = Undefined Or (IndexInArray + Direction < 0) Then
				Continue;
			EndIf;
			
			LineIndex = BundleComponents.IndexOf(Row);
			DirectionIndex = BundleComponents.IndexOf(Rows[IndexInArray + Direction]);
			BundleComponents.Move(LineIndex, DirectionIndex - LineIndex);
			
		EndDo;
		
	EndIf;
	
	RefreshRowFilter(BundleComponents, CurrentCharacteristic);
	
EndProcedure

&AtServer
Procedure ReplaceComponents()
	
	BundleComponents.Clear();
	
	If Not ValueIsFilled(NewBundleProduct) Then
		Return;
	EndIf; 
	
	Items.NewBundleProduct.WarningOnEditRepresentation = WarningOnEditRepresentation.DontShow;
	Items.NewBundleCharacteristic.WarningOnEditRepresentation = WarningOnEditRepresentation.DontShow;
	
	NewBundleComponents = BundlesServer.BundlesComponents(NewBundleProduct, NewBundleCharacteristic);
	
	For Each TableLine In NewBundleComponents Do
		
		NewRow = BundleComponents.Add();
		FillPropertyValues(NewRow, TableLine);
		NewRow.BundleCharacteristic = NewBundleCharacteristic;
		NewRow.BundleProduct = NewBundleProduct;
		NewRow.Quantity = NewRow.Quantity * Quantity;
		
	EndDo;
	
	// Characteristics
	If Not ThisObject.SaveChanges Then
		FillUseCharacteristicAttributes()
	EndIf;
	// End Characteristics
	
	UseCharacteristics = Common.ObjectAttributeValue(NewBundleProduct, "UseCharacteristics");
	FormManagement(ThisObject);
	
EndProcedure

&AtServerNoContext
Function  BundleCharacteristic(Products, Text)
	
	ParametersStructure = New Structure();
	
	If IsBlankString(Text) Then
		ParametersStructure.Insert("SearchRow", Undefined);
	Else
		ParametersStructure.Insert("SearchRow", Text);
	EndIf;
	
	ParametersStructure.Insert("Filter", New Structure);
	ParametersStructure.Filter.Insert("Owner", Products);
	Return Catalogs.ProductsCharacteristics.GetChoiceData(ParametersStructure);
	
EndFunction

&AtServer
// Refreshing of conditional appearance for characteristics column
// Form - Managed form
Procedure RefreshConditionalAppearanceForCharacteristicsTable(Form)
	
	FieldName = "BundleComponentsCharacteristic";
	SearchValue = Form.Items.Find(FieldName);
	
	If Not SearchValue = Undefined Then
		
		FieldCheckCharacteristicsFilling = SearchValue.Parent.DataPath + ".CheckCharacteristicsFilling";
		FieldUseCharacteristics = SearchValue.Parent.DataPath + ".UseCharacteristics";
		FieldCharacteristics = FieldName; 
		
		NewConditionalAppearance = Form.ConditionalAppearance.Items.Add();
		
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, FieldUseCharacteristics, False, DataCompositionComparisonType.Equal);
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, FieldCharacteristics);
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", NStr("en = '<Not used>'; ru = '<Не используется>';pl = '<Nie używane>';es_ES = '<No se usa>';es_CO = '<No se usa>';tr = '<Kullanılmıyor>';it = '<Non utilizzato>';de = '<Nicht verwendet>'"));
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.UnavailableTabularSectionTextColor);
		
		If Not ChoiceMode Then
			
			NewConditionalAppearance = Form.ConditionalAppearance.Items.Add();
			WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
				FieldCheckCharacteristicsFilling,
				True,
				DataCompositionComparisonType.Equal);
			WorkWithForm.AddAppearanceField(NewConditionalAppearance, FieldCharacteristics);
			WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", True);
			
			NewConditionalAppearance = Form.ConditionalAppearance.Items.Add();
			WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
				SearchValue.Parent.DataPath + ".Characteristic",
				Catalogs.ProductsCharacteristics.EmptyRef(),
				DataCompositionComparisonType.NotEqual);
			WorkWithForm.AddAppearanceField(NewConditionalAppearance, FieldCharacteristics);
			WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillUseCharacteristicAttributes()
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	CAST(DocumentProductsTable.Products AS Catalog.Products) AS Ref,
	|	DocumentProductsTable.Characteristic AS Characteristic
	|INTO DocumentProductsTable
	|FROM
	|	&DocumentProductsTable AS DocumentProductsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentProductsTable.Ref.UseCharacteristics AS UseCharacteristics,
	|	DocumentProductsTable.Ref AS Products
	|FROM
	|	DocumentProductsTable AS DocumentProductsTable";
	
	DocumentProductsTable = BundleComponents.Unload(, "Products, Characteristic");
	
	Query.SetParameter("DocumentProductsTable",DocumentProductsTable);
	CharacteristicsSelection = Query.Execute().Select();
	
	While CharacteristicsSelection.Next() Do
		
		RowFilter = New Structure("Products", CharacteristicsSelection.Products);
		
		FoundRows = BundleComponents.FindRows(RowFilter);
		
		For Each Row In FoundRows Do
			FillPropertyValues(Row, CharacteristicsSelection);
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

