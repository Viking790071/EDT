#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function AvailableProductsFields() Export
	
	AvailableFields = New ValueTable;
	AvailableFields.Columns.Add("Use");
	AvailableFields.Columns.Add("ProductsAttribute");
	AvailableFields.Columns.Add("AttributePresentation");
	AvailableFields.Columns.Add("Width");
	AvailableFields.Columns.Add("DetailsParameter");
	AvailableFields.Columns.Add("ServiceVisibilityManagement");
	
	UseCharacteristics = GetFunctionalOption("UseCharacteristics");
	
	AddRowInAttributesTable(AvailableFields, True, "Picture", NStr("en='Picture'; ru = 'Картинка';pl = 'Obrazek';es_ES = 'Imagen';es_CO = 'Imagen';tr = 'Resim';it = 'Immagine';de = 'Bild'"), 8, "ProductsRef");
	AddRowInAttributesTable(AvailableFields, True, "Code", NStr("en='Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"), 11, "ProductsRef");
	AddRowInAttributesTable(AvailableFields, True, "SKU", NStr("en='Product ID'; ru = 'Идентификатор номенклатуры';pl = 'Artykuł produktowy';es_ES = 'ID de producto';es_CO = 'ID de producto';tr = 'Ürün kodu';it = 'ID articolo';de = 'Produkt-ID'"), 11, "ProductsRef");
	AddRowInAttributesTable(AvailableFields, True, "Description", NStr("en='Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"), 30, "ProductsRef");
	AddRowInAttributesTable(AvailableFields, True, "DescriptionFull", NStr("en='Detailed description'; ru = 'Подробное описание';pl = 'Szczegółowy opis';es_ES = 'Descripción detallada';es_CO = 'Descripción detallada';tr = 'Ayrıntılı açıklama';it = 'Descrizione dettagliata';de = 'Detaillierte Beschreibung'"), 30, "ProductsRef");
	AddRowInAttributesTable(AvailableFields, True, "Comment", NStr("en='Comment'; ru = 'Комментарий';pl = 'Uwagi';es_ES = 'Comentario';es_CO = 'Comentario';tr = 'Yorum';it = 'Commento';de = 'Kommentar'"), 30, "ProductsRef");
	AddRowInAttributesTable(AvailableFields, True, "CountryOfOrigin", NStr("en='Country'; ru = 'Страна';pl = 'Państwo';es_ES = 'País';es_CO = 'País';tr = 'Ülke';it = 'Paese';de = 'Länder-'"), 7, "ProductsRef");
	AddRowInAttributesTable(AvailableFields, False, "FreeBalance", NStr("en = 'Available quantity'; ru = 'Доступное количество';pl = 'Dostępna ilość';es_ES = 'Cantidad disponible';es_CO = 'Cantidad disponible';tr = 'Mevcut miktar';it = 'Quantità disponibile';de = 'Verfügbare Menge'"), 10, "ProductsRef");
	
	AddRowInAttributesTable(AvailableFields,
		UseCharacteristics,
		"Characteristic",
		NStr("en='Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"),
		14,
		"DetailsCharacteristic",
		UseCharacteristics);
		
	Return AvailableFields;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.PriceLists);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Internal

#Region LibrariesHandlers

// StandardSubsystems.ObjectVersioning
Procedure OnDefineObjectVersioningSettings(Settings) Export
	
EndProcedure
// End StandardSubsystems.ObjectVersioning

// StandardSubsystems.ObjectAttributesLock
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	Return AttributesToLock;
	
EndFunction
// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region Private

Procedure AddRowInAttributesTable(AvailableFields,
	Use,
	ProductsAttribute,
	AttributePresentatiion,
	Width,
	DetailsParameter = "",
	ServiceVisibilityManagement = True)
	
	NewRow								= AvailableFields.Add();
	NewRow.Use							= Use;
	NewRow.ProductsAttribute			= ProductsAttribute;
	NewRow.AttributePresentation		= AttributePresentatiion;
	NewRow.DetailsParameter				= DetailsParameter;
	NewRow.Width						= Width;
	NewRow.ServiceVisibilityManagement	= ServiceVisibilityManagement;
	
EndProcedure

#EndRegion

#EndIf