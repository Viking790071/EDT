
#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Fill property tree by values.
//
Procedure FillValuesPropertiesTree(WrapValuesEntered)
	
	If WrapValuesEntered Then
		DrivePropertiesManagement.MovePropertiesValues(Object.AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	EndIf;
	
	PrListOfSets = New ValueList;
	Set = ProductsCategory.SetOfCharacteristicProperties;
	If Set <> Undefined Then
		PrListOfSets.Add(Set);
	EndIf;
	
	Tree = DrivePropertiesManagement.FillValuesPropertiesTree(Object.Ref, Object.AdditionalAttributes, True, PrListOfSets);
	ValueToFormAttribute(Tree, "PropertiesValuesTree");
	
EndProcedure

&AtServerNoContext
// Function returns products owner category.
//
Function GetOwnerProductsCategory(ProductsOwner)
	
	Return ProductsOwner.ProductsCategory;
	
EndFunction

&AtClient
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

&AtClient
// Function sets new characteristic description by the property values.
//
// Parameters:
//  PropertiesValuesCollection - a value collection with property Value.
//
// Returns:
//  String - generated description.
//
Function GenerateDescription(PropertiesValuesCollection)

	TreeItems = PropertiesValuesCollection.GetItems();
	
	String = "";
	RecursiveBypassOfValueTree(TreeItems, String);
	
	String = Left(String, StrLen(String) - 2);

	If IsBlankString(String) Then
		String =Nstr("en = '<Attributes aren''t set>'; ru = '<Реквизиты не установлены>';pl = '<Nie ustawiono atrybutów>';es_ES = '<Los atributos no están configurados>';es_CO = '<Los atributos no están configurados>';tr = '<Öznitelikler ayarlanmadı>';it = '<attributi non sono impostati>';de = '<Attribute sind nicht gesetzt>'");
	EndIf;

	Return String;

EndFunction

&AtServer
// Procedure - fills choice list for attribute Owner.
//
Procedure FillChoiceListOwner()
	
	Items.Owner.ChoiceList.Clear();
	If ValueIsFilled(ProductsCategory) Then
		Items.Owner.ChoiceList.Add(ProductsCategory);
	EndIf;
	If ValueIsFilled(Products) Then
		Items.Owner.ChoiceList.Add(Products);
	EndIf;
	
EndProcedure

&AtClient
// Procedure - fills choice list for attribute Description.
//
Procedure FillChoiceListItems()
	
	Items.Description.ChoiceList.Clear();
	Items.Description.ChoiceList.Add(GenerateDescription(PropertiesValuesTree));
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	// Filling.
	If Parameters.Property("FillingValues") AND Parameters.FillingValues.Property("Owner") Then
		
		If TypeOf(Parameters.FillingValues.Owner) = Type("CatalogRef.Products") Then
		
			ProductsCategory = Parameters.FillingValues.Owner.ProductsCategory;
			Products = Parameters.FillingValues.Owner;
			
		ElsIf TypeOf(Parameters.FillingValues.Owner) = Type("CatalogRef.ProductsCategories") Then
			
			ProductsCategory = Parameters.FillingValues.Owner;
			Products = Undefined;
			
		ElsIf TypeOf(Parameters.FillingValues.Owner) = Type("ValueList") Then
			
			For Each ListIt In Parameters.FillingValues.Owner Do
				
				If TypeOf(ListIt.Value) = Type("CatalogRef.ProductsCategories") Then
					
					ProductsCategory = ListIt.Value;
					
				Else
					
					Object.Owner = ListIt.Value;
					Products = ListIt.Value;
					
				EndIf;
				
			EndDo;
		
		EndIf;
		
	// Copying.
	ElsIf Parameters.Property("CopyingValue")
		And ValueIsFilled(Parameters.CopyingValue) Then
		
		CopyingValueOwner = Common.ObjectAttributeValue(Parameters.CopyingValue, "Owner");
		If ValueIsFilled(CopyingValueOwner) And TypeOf(CopyingValueOwner) = Type("CatalogRef.Products") Then
			
			ProductsCategory = Common.ObjectAttributeValue(CopyingValueOwner, "ProductsCategory");
			Products = CopyingValueOwner;
			
		ElsIf ValueIsFilled(CopyingValueOwner) And TypeOf(CopyingValueOwner) = Type("CatalogRef.ProductsCategories") Then
			
			ProductsCategory = CopyingValueOwner;
			Products = Undefined;
			
		EndIf;
		
	// Open.
	ElsIf ValueIsFilled(Parameters.Key) Then
		
		If TypeOf(Parameters.Key.Owner) = Type("CatalogRef.Products") Then
		
			ProductsCategory = Parameters.Key.Owner.ProductsCategory;
			Products = Parameters.Key.Owner;
			
		ElsIf TypeOf(Parameters.Key.Owner) = Type("CatalogRef.ProductsCategories") Then
			
			ProductsCategory = Parameters.Key.Owner;
			Products = Undefined;

		EndIf;
		
	Else
		
		ProductsCategory = Undefined;
		Products = Undefined;
		
	EndIf;
	// Checking.
	If ValueIsFilled(Object.Owner)
		And (TypeOf(Object.Owner) = Type("CatalogRef.Products")
			Or TypeOf(Object.Owner) = Type("CatalogRef.ProductsCategories"))
		And Not Common.ObjectAttributeValue(Object.Owner, "UseCharacteristics") Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Accounting by variants is not applied to the product.
								|Select the ""Variants"" checkbox in the product card.'; 
								|ru = 'Для номенклатуры не ведется учет по вариантам.
								|Установите флажок ""Варианты"" в карточке номенклатуры.';
								|pl = 'Ewidencja według wariantów nie jest zastosowana dla produktu.
								|Zaznacz pole wyboru ""Warianty"" w karcie produkty.';
								|es_ES = 'La contabilidad por variantes no se aplica al producto*
								|Seleccione la casilla de verificación ""Variantes"" en la ficha del producto.';
								|es_CO = 'La contabilidad por variantes no se aplica al producto*
								|Seleccione la casilla de verificación ""Variantes"" en la ficha del producto.';
								|tr = 'Varyantlara göre muhasebe ürüne uygulanmıyor.
								|Ürün kartında ""Varyantlar"" onay kutusunu işaretleyin.';
								|it = 'La contabilità per varianti non è applicata all''articolo.
								|Selezionare la casella di controllo ""Varianti"" nella scheda articolo.';
								|de = 'Buchhaltung nach Varianten ist nicht für den Produkt anwendbar.
								|Aktivieren Sie das Kontrollkästchen ""Varianten"" in der Produktkarte.'");
		Message.Message();
		Cancel = True;
	EndIf;
	
	// Fill the property value tree.
	If Not Cancel Then
		FillChoiceListOwner();
		FillValuesPropertiesTree(False);
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
// Event handler procedure OnOpen.
//
Procedure OnOpen(Cancel)
	
	// Deploy property value tree.
	DriveClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	FillChoiceListItems();
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Transfer the values from property value tree in tabular object section.
	DrivePropertiesManagement.MovePropertiesValues(CurrentObject.AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange field Owner.
//
Procedure OwnerOnChange(Item)
	
	If TypeOf(Object.Owner) = Type("CatalogRef.Products") Then
		
		ProductsCategory = GetOwnerProductsCategory(Object.Owner);
		
	ElsIf TypeOf(Object.Owner) = Type("CatalogRef.ProductsCategories") Then
		
		ProductsCategory = Object.Owner;
		
	Else
		
		ProductsCategory = Undefined;
		
	EndIf;
	
	// Fill the property value tree.
	FillValuesPropertiesTree(True);
	
	DriveClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Properties
&AtClient
Procedure PropertyValueTreeOnChange(Item)
	
	Object.Description = GenerateDescription(PropertiesValuesTree);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTreeBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTreeBeforeDelete(Item, Cancel)
	
	DriveClient.PropertyValueTreeBeforeDelete(Item, Cancel, Modified);
	
EndProcedure

&AtClient
Procedure PropertyValueTreeOnStartEdit(Item, NewRow, Copy)
	
	DriveClient.PropertyValueTreeOnStartEdit(Item);
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#EndRegion
