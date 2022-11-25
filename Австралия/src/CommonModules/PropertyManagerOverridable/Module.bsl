#Region Public

// Fills object property sets. Usually required if there is more than one set.
//
// Parameters:
//  Object - AnyRef - a reference to an object with properties.
//               - ClientApplicationForm - a form of the object to which properties are attached.
//               - FormDataStructure - a description of the object to which properties are attached.
//
//  RefType - Type - a type of the property owner reference.
//
//  PropertySets - ValueTable - with columns:
//                    Set - CatalogRef.AdditionalAttributesAndInfoSets.
//                    CommonSet - Boolean - True if the property set contains properties common for 
//                     all objects.
//                    // Then, form item properties of the FormGroup type and the usual group kind
//                    // or page that is created if there are more than one set excluding
//                    // a blank set that describes properties of deleted attributes group.
//                    
//                    // If the value is Undefined, use the default value.
//                    
//                    // For any managed form group.
//                    Height - a number.
//                    Header - a string.
//                    Hint - a string.
//                    VerticalStretch - Boolean.
//                    HorizontalStretch - Boolean.
//                    ReadOnly - Boolean.
//                    TitleTextColor - a color.
//                    Width - a number.
//                    TitleFont - a font.
//                    
//                    // For usual group and page.
//                    Grouping - ChildFormItemsGroup.
//                    
//                    // For usual group.
//                    Representation - UsualGroupRepresentation.
//                    
//                    // For page.
//                    Picture - a picture.
//                    DisplayTitle - Boolean.
//
//  StandardProcessing - Boolean - initial value is True. Shows whether to get the default set when 
//                         PropertySets.Quantity() is equal to zero.
//
//  AssignmentKey - Undefined - (initial value) - specifies to calculate the assignment key 
//                      automatically and add PurposeUseKey and WindowOptionsKey to form property 
//                      values to save form changes (settings, position, and size) separately for 
//                      different sets.
//                      
//                      For example, for each product kind - its own sets.
//
//                    - String - (not more than 32 characters) - use the specified assignment key to 
//                      add it to form property values.
//                      Blank string - do not change form key properties as they are set in the form 
//                      and already consider differences of sets.
//
//                    Addition has format "PropertySetKey<AssignmentKey>" to be able to update 
//                    <AssignmentKey> without re-adding.
//                    Upon automatic calculation, <AssignmentKey> contains reference ID hash of 
//                    ordered property sets.
//
Procedure FillObjectPropertySets(Object, RefType, PropertySets, StandardProcessing, AssignmentKey) Export
	
	If RefType = Type("CatalogRef.Products") AND NOT Object.IsFolder Then
		SetList = GetProductsAdditionalAttributes(Object);
	Else
		Return;
	EndIf;
	
	For Each Item In SetList Do
		
		NewItem = PropertySets.Add();
		NewItem.Title	= Item.Presentation;
		NewItem.Set		= Item.Value;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Function GetProductsAdditionalAttributes(Object)
	
	SetList = New ValueList;
	
	CommonSet = Catalogs.AdditionalAttributesAndInfoSets.Catalog_Products_Common;
	SetList.Add(CommonSet, NStr("en = 'Common properties'; ru = 'Общие свойства';pl = 'Wspólne właściwości';es_ES = 'Propiedades comunes';es_CO = 'Propiedades comunes';tr = 'Ortak özellikler';it = 'Proprietà comuni';de = 'Allgemeine Eigenschaften'"));
	
	GroupSet = Common.ObjectAttributeValue(Object.ProductsCategory, "PropertySet");
	SetList.Add(GroupSet, NStr("en = 'Product group properties'; ru = 'Свойства номенклатурной группы';pl = 'Właściwości grupy produktów';es_ES = 'Propiedades del grupo de productos';es_CO = 'Propiedades del grupo de productos';tr = 'Ürün grubu özellikleri';it = 'Proprietà del gruppo articolo';de = 'Eigenschaften der Produktgruppe'"));	
	
	Return SetList;
	
EndFunction

#EndRegion
