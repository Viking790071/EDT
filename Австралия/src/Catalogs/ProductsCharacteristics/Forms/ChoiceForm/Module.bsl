#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Sets filter for product variant choice form.
//
Procedure SetFilterByOwnerAtServer()
	
	FilterList = New ValueList;
	FilterList.Add(Products);
	FilterList.Add(ProductsCategory);
	
	DriveClientServer.SetListFilterItem(List,"Owner",FilterList,True,DataCompositionComparisonType.InList);
	
EndProcedure

&AtClient
// Sets filter for product variant choice form.
//
Procedure SetFilterByOwnerAtClient()
	
	FilterList = New ValueList();
	FilterList.Add(Products);
	FilterList.Add(ProductsCategory);
	
	DriveClientServer.SetListFilterItem(List,"Owner",FilterList,True,DataCompositionComparisonType.InList);
	
EndProcedure

&AtServer
// Fill property tree by values.
//
Procedure FillValuesPropertiesTree(WrapValuesEntered, AdditionalAttributes)
	
	If WrapValuesEntered Then
		DriveServer.MovePropertiesValues(AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	EndIf;
	
	PrListOfSets = New ValueList;
	Set = ProductsCategory.SetOfCharacteristicProperties;
	If Set <> Undefined Then
		PrListOfSets.Add(Set);
	EndIf;
	
	Tree = DriveServer.FillValuesPropertiesTree(ProductsCategory, AdditionalAttributes, True, PrListOfSets);
	ValueToFormAttribute(Tree, "PropertiesValuesTree");
	
EndProcedure

&AtClient
// Procedure traverses the value tree recursively.
//
Procedure SetFilterByPropertiesAndValues(TreeItems)
	
	For Each TreeRow In TreeItems Do
		
		If ValueIsFilled(TreeRow.Value) Then
			
			DriveClientServer.SetListFilterItem(List,"Ref.[" + String(TreeRow.Property)+"]",TreeRow.Value);
			
		EndIf;
		
		NextTreeItem = TreeRow.GetItems();
		SetFilterByPropertiesAndValues(NextTreeItem);
		
	EndDo;
	
EndProcedure

&AtServer
// Procedure traverses the value tree recursively.
//
Procedure RecursiveBypassOfValueTree(TreeItems, String)
	
	For Each TreeRow In TreeItems Do
		
		If ValueIsFilled(TreeRow.Value) Then
			If IsBlankString(TreeRow.FormatProperties) Then
				String = String + TreeRow.Value + ", ";
			Else
				String = String + Format(TreeRow.Value, TreeRow.FormatProperties) + ", ";
			EndIf;
		EndIf;
		
		NextTreeItem = TreeRow.GetItems();
		RecursiveBypassOfValueTree(NextTreeItem, String);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - setting the filter for choice form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.Products") Then
		
		Products = Parameters.Filter.Owner;
		ProductsCategory = Parameters.Filter.Owner.ProductsCategory;
		
		MessageText = "";
		If Not ValueIsFilled(Products) Then
			MessageText = NStr("en = 'Product is required.'; ru = 'Укажите номенклатуру.';pl = 'Wymagany jest produkt.';es_ES = 'Se requiere un producto.';es_CO = 'Se requiere un producto.';tr = 'Ürün gerekli.';it = 'È richiesto l''articolo.';de = 'Produkte ist ein Pflichtfeld.'");
		ElsIf Parameters.Property("ThisIsReceiptDocument") AND Products.ProductsType = Enums.ProductsTypes.Service Then
			MessageText = NStr("en = 'Accounting by variants is not kept for services of external counterparties.'; ru = 'Для услуг сторонних контрагентов не ведется учет по вариантам!';pl = 'Dla kontrahentów zewnętrznych nie jest prowadzona ewidencja według wariantów.';es_ES = 'Contabilidad por variantes no se ha guardado para los servicios de las contrapartes externas.';es_CO = 'Contabilidad por variantes no se ha guardado para los servicios de las contrapartes externas.';tr = 'Harici cari hesapların hizmetleri için değişkenler bazında muhasebe yapılmaz.';it = 'La contabilità per varianti non è gestita per servizi di controparti esterne.';de = 'Die Abrechnung nach Varianten erfolgt nicht für Dienstleistungen externer Geschäftspartner.'");
		ElsIf Not Products.UseCharacteristics Then
			MessageText = NStr("en = 'Inventory tracking by variant is disabled.
				|To turn it on, go to Settings > Purchases/Warehouse,
				|and under ""Inventory (Products)"", select ""Inventory accounting by variants"".'; 
				|ru = 'Учет запасов по вариантам отключен.
				|Чтобы включить его, перейдите в меню Настройки > Закупки/Склад
				|и в разделе ""Запасы (номенклатура)"" установите флажок ""Учет запасов в разрезе вариантов"".';
				|pl = 'Śledzenie zapasów według wariantów jest wyłączone.
				|W celu włączenia przejdź do Ustawienia > Zakup/Magazyn,
				|i w ""Zapasy (Produkty)"", zaznacz ""Ewidencja zapasów według wariantów"".';
				|es_ES = 'El rastreo de inventario por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|es_CO = 'El rastreo de inventario por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|tr = 'Varyantlara göre stok takibi kapalı.
				|Açmak için, Ayarlar > Satın alma / Ambar sayfasının
				|""Stok (Ürünler)"" bölümünde ""Varyantlara göre envanter muhasebesi""ni seçin.';
				|it = 'Il tracciamento delle scorte per variante è disattivato.
				|Per attivarlo, andare in Impostazioni > Acquisti/Magazzino,
				|e in ""Scorte (Articoli)"", selezionare ""Contabilità scorte secondo varianti"".';
				|de = 'Bestandsverfolgung nach Variante ist deaktiviert. Um sie zu aktivieren:
				|. Gehen Sie zu Einstellungen > Einkäufe / Lager,
				| und aktivieren Sie ""Bestandsbuchhaltung nach Varianten"" unter ""Bestand (Produkte)"".'");
		EndIf;
		
		If Not IsBlankString(MessageText) Then
			If Not UsersClientServer.IsExternalUserSession() Then
				CommonClientServer.MessageToUser(MessageText,,,,Cancel);
			Else
				Cancel = True;
			EndIf;
			Return;
		EndIf;
		
		// Clean the passed filter and set its
		Parameters.Filter.Delete("Owner");
		SetFilterByOwnerAtServer();
		
		// Fill the property value tree.
		FillValuesPropertiesTree(False, Parameters.CurrentRow.AdditionalAttributes);
		
	Else
		
		Items.ListCreate.Enabled = False;
		Items.ListContextMenuCreate.Enabled = False;
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
// Event handler procedure OnOpen.
//
Procedure OnOpen(Cancel)
	
	// Develop the property value tree.
	DriveClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	
EndProcedure

#Region TabularSectionAttributeEventHandlersPropertiesAndValues

&AtClient
// Procedure - event handler OnChange input field Value.
//
Procedure ValueOnChange(Item)
	
	List.SettingsComposer.Settings.Filter.Items.Clear();
	
	SetFilterByOwnerAtClient();
	
	TreeItems = PropertiesValuesTree.GetItems();
	SetFilterByPropertiesAndValues(TreeItems);
	
EndProcedure

#EndRegion

#Region TabularSectionAttributeEventHandlersCharacteristics

&AtClient
// Procedure - event handler BeforeAddStart input field List.
//
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy = True Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FillingValues = New Structure;
	FillingValues.Insert("Owner", Products);
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	
	OpenForm("Catalog.ProductsCharacteristics.ObjectForm", FormParameters);
	
EndProcedure

#EndRegion

#Region PropertyMechanismProcedures

&AtClient
// Procedure - event handler OnChange input field PropertyValueTree.
//
Procedure PropertyValueTreeOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeAddStart input field PropertyValueTree.
//
Procedure PropertyValueTreeBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeDelete input field PropertyValueTree.
//
Procedure PropertyValueTreeBeforeDelete(Item, Cancel)
	
	DriveClient.PropertyValueTreeBeforeDelete(Item, Cancel, Modified);
	
EndProcedure

&AtClient
// Procedure - event handler WhenEditStart input field PropertyValueTree.
//
Procedure PropertyValueTreeOnStartEdit(Item, NewRow, Copy)
	
	DriveClient.PropertyValueTreeOnStartEdit(Item);
	
EndProcedure

#EndRegion

#EndRegion
