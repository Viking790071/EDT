#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns the structure with the parameters of selection processor
//
// It is used for caching
//
Procedure InformationAboutDocumentStructure(ParametersStructure) Export
	
	ParametersStructure = New Structure;
	
	For Each DataProcessorAttribute In Metadata.DataProcessors.ProductsSelection.Attributes Do
		
		ParametersStructure.Insert(DataProcessorAttribute.Name);
		
	EndDo;
	
EndProcedure

// Returns the structure of the mandatory parameters
//
Function MandatoryParametersStructure()
	
	Return New Structure("Date, ProductsType, OwnerFormUUID",
						NStr("en = 'Date'; ru = 'Дата';pl = 'Data';es_ES = 'Fecha';es_CO = 'Fecha';tr = 'Tarih';it = 'Data';de = 'Datum'"),
						NStr("en = 'Product type'; ru = 'Тип номенклатуры';pl = 'Typ produktu';es_ES = 'Tipo de producto';es_CO = 'Tipo de producto';tr = 'Ürün türü';it = 'Tipo di articolo';de = 'Produktart'"),
						NStr("en = 'Unique identifier of the owner form'; ru = 'Уникальный идентификатор формы владельца';pl = 'Unikalny identyfikator właściciela formularza';es_ES = 'Identificador único del formulario del propietario';es_CO = 'Identificador único del formulario del propietario';tr = 'Sahibin formunun benzersiz tanımlayıcısı';it = 'ID univoco del modulo proprietario';de = 'Eindeutige Kennung des Besitzerformulars'"));
	
EndFunction

// Check a minimum level parameters filling
//
Procedure CheckParametersFilling(SelectionParameters, Cancel) Export
	Var Errors;
	
	MandatoryParametersStructure = MandatoryParametersStructure();
	
	For Each StructureItem In MandatoryParametersStructure Do
		
		ValueParameters = Undefined;
		If Not SelectionParameters.Property(StructureItem.Key, ValueParameters) Then
			
			ErrorText = NStr("en = 'Required parameter (%1) required for opening of products selection form is missing.'; ru = 'Отсутствует обязательный параметр (%1), необходимый для открытия формы подбора номенклатуры.';pl = 'Brak wymaganego parametru (%1), niezbędnego do otwarcia formularza wyboru produktów.';es_ES = 'Parámetro necesario (%1) requerido para abrir el formulario de selección de productos está faltando.';es_CO = 'Parámetro necesario (%1) requerido para abrir el formulario de selección de productos está faltando.';tr = 'Ürün seçim formunun açılması için gerekli olan parametre (%1) eksik.';it = 'Il parametro richiesto (%1) richiesto per l''apertura di un modulo di selezione articoli è mancante.';de = 'Der erforderliche Parameter (%1), der zum Öffnen des Produktauswahlformulars benötigt wird, fehlt.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, StructureItem.Value);
			
			CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
			
		ElsIf Not ValueIsFilled(ValueParameters) Then
			
			ErrorText = NStr("en = 'Required parameter (%1) required for opening of products selection form is filled in incorrectly.'; ru = 'Неверно заполнен обязательный параметр (%1), необходимый для открытия формы подбора номенклатуры.';pl = 'Wymagany parametr (%1), niezbędny do otwarcia formularza wyboru produktu, jest niepoprawnie wypełniony.';es_ES = 'Parámetro necesario (%1) requerido para abrir el formulario de selección de productos está rellenado de forma incorrecta.';es_CO = 'Parámetro necesario (%1) requerido para abrir el formulario de selección de productos está rellenado de forma incorrecta.';tr = 'Ürün seçim formunun açılması için gerekli olan parametre (%1) yanlış dolduruldu.';it = 'Il parametro richiesto (%1) richiesto per l''apertura di un modulo di selezione articoli è inserito in modo errato.';de = 'Der erforderliche Parameter (%1), der zum Öffnen des Formulars zur Produktauswahl benötigt wird, ist falsch ausgefüllt.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, StructureItem.Value);
			
			CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
			
		EndIf;
		
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
EndProcedure

// Function returns a full name of the selection form 
//
Function ChoiceFormFullName() Export
	
	Return "DataProcessor.ProductsSelection.Form.MainForm";
	
EndFunction

#EndRegion

#EndIf