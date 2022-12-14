#Region Internal

// Returns a flag that shows if there are any common separators in the configuration.
//
// Returns:
//   Boolean - True if the configuration is separated.
//
Function IsSeparatedConfiguration() Export
	
	HasSeparators = False;
	For each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			HasSeparators = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasSeparators;
	
EndFunction

// Returns a flag that shows whether the metadata object is used in common separators.
//
// Parameters:
//   FullNameOfMetadataObject - String - name of the metadata object.
//   Separator - String - the name of the common separator that is checked if it separates the metadata object.
//
// Returns:
//   Boolean - True if the object is separated.
//
Function IsSeparatedMetadataObject(Val FullMetadataObjectName, Val Separator = Undefined) Export
	
	If Separator = Undefined Then
		SeparationByMainAttribute = SaaS.SeparatedMetadataObjects(SaaS.MainDataSeparator());
		SeparationByAuxiliaryAttribute = SaaS.SeparatedMetadataObjects(SaaS.AuxiliaryDataSeparator());
		Result = SeparationByMainAttribute.Get(FullMetadataObjectName) <> Undefined
			Or SeparationByAuxiliaryAttribute.Get(FullMetadataObjectName) <> Undefined;
		Return Result;
	Else
		SeparatedMetadataObjects = SaaS.SeparatedMetadataObjects(Separator);
		Return SeparatedMetadataObjects.Get(FullMetadataObjectName) <> Undefined;
	EndIf;
	
EndFunction

// Returns the data separation mode flag (conditional separation).
// 
// 
// Returns False if the configuration does not support data separation mode (does not contain 
// attributes to share).
//
// Returns:
//  Boolean - True if separation is enabled.
//         - False is separation is disabled or not supported.
//
Function DataSeparationEnabled() Export
	
	If Not IsSeparatedConfiguration() Then
		Return False;
	EndIf;
	
	If Not GetFunctionalOption("SaaS") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns an array of??serialized structural types currently supported.
//
// Returns:
//   FixedArray - items of Type type.
//
Function StructuralTypesToSerialize() Export
	
	TypesArray = New Array;
	
	TypesArray.Add(Type("Structure"));
	TypesArray.Add(Type("FixedStructure"));
	TypesArray.Add(Type("Array"));
	TypesArray.Add(Type("FixedArray"));
	TypesArray.Add(Type("Map"));
	TypesArray.Add(Type("FixedMap"));
	TypesArray.Add(Type("KeyAndValue"));
	TypesArray.Add(Type("ValueTable"));
	
	Return New FixedArray(TypesArray);
	
EndFunction

// Returns the endpoint to send messages to the service manager.
//
// Returns:
//  ExchangePlanRef.MessageExchange - node matching the service manager.
//
Function ServiceManagerEndpoint() Export
	
	ModuleToCall = Common.CommonModule("SaaSCTL");
	Return ModuleToCall.ServiceManagerEndpoint();
	
EndFunction

// Returns mapping between user contact information kinds and kinds.
// Contact information used in the XDTO SaaS.
//
// Returns:
//  Map - mapping between CI kinds.
//
Function ContactInformationKindAndXDTOUserMap() Export
	
	Map = New Map;
	Map.Insert(Catalogs.ContactInformationKinds.UserEmail, "UserEMail");
	Map.Insert(Catalogs.ContactInformationKinds.UserPhone, "UserPhone");
	
	Return New FixedMap(Map);
	
EndFunction

// Returns mapping between user contact information kinds and XDTO kinds.
// User CI.
//
// Returns:
//  Map - mapping between CI kinds.
//
Function XDTOContactInformationKindAndUserContactInformationKindMap() Export
	
	Map = New Map;
	For each KeyAndValue In ContactInformationKindAndXDTOUserMap() Do
		Map.Insert(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	Return New FixedMap(Map);
	
EndFunction

// Returns mapping between XDTO rights used in SaaS and possible actions with SaaS user.
// 
// 
// Returns:
//  Map - mapping between rights and actions.
//
Function XDTORightAndServiceUserActionMap() Export
	
	Map = New Map;
	Map.Insert("ChangePassword", "ChangePassword");
	Map.Insert("ChangeName", "ChangeName");
	Map.Insert("ChangeFullName", "ChangeFullName");
	Map.Insert("ChangeAccess", "ChangeAccess");
	Map.Insert("ChangeAdmininstrativeAccess", "ChangeAdministrativeAccess");
	
	Return New FixedMap(Map);
	
EndFunction

// Returns data model details of data area.
//
// Returns:
//  FixedMap - area data model
//    * Key - MetadataObject - a metadata object,
//    * Value - String - the name of the common attribute separator.
//
Function GetDataAreaModel() Export
	
	Result = New Map();
	
	MainDataSeparator = SaaS.MainDataSeparator();
	MainAreaData = SeparatedMetadataObjects(
		MainDataSeparator);
	For Each MainAreaDataItem In MainAreaData Do
		Result.Insert(MainAreaDataItem.Key, MainAreaDataItem.Value);
	EndDo;
	
	AuxiliaryDataSeparator = SaaS.AuxiliaryDataSeparator();
	AuxiliaryAreaData = SaaS.SeparatedMetadataObjects(
		AuxiliaryDataSeparator);
	For Each AuxiliaryAreaDataItem In AuxiliaryAreaData Do
		Result.Insert(AuxiliaryAreaDataItem.Key, AuxiliaryAreaDataItem.Value);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns an array of the separators that are in the configuration.
//
// Returns:
//   FixedArray - an array of common attribute names used as separators.
//     
//
Function ApplicationSeparators() Export
	
	SeparatorArray = New Array;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			SeparatorArray.Add(CommonAttribute.Name);
		EndIf;
	EndDo;
	
	Return New FixedArray(SeparatorArray);
	
EndFunction

// Returns the common attribute content by the passed name.
//
// Parameters:
//   Name - String - common attribute name.
//
// Returns:
//   CommonAttributeContent - list of metadata objects that include the??common attribute.
//
Function CommonAttributeContent(Val Name) Export
	
	Return Metadata.CommonAttributes[Name].Content;
	
EndFunction

// Returns a list of full names of all metadata objects used in the common separator attribute 
//  (whose name is passed in the Separator parameter) and values of the object metadata properties 
//  that can be required for further processing in universal algorithms.
// In case of sequences and document journals the function determines whether they are separated by included documents: any one from the sequence or journal.
//
// Parameters:
//  Separator - string, name of the common separator.
//
// Returns:
// FixedMap,
//  Key - string, full name of the metadata object,
//  Value - FixedStructure,
//    Name - string, name of the metadata object,
//    Separator - string, name of the separator that separates the metadata object,
//    ConditionalSeparation - String - full name of the metadata object that shows whether the 
//      metadata object data separation is enabled.
//
Function SeparatedMetadataObjects(Val Separator) Export
	
	Result = New Map;
	
	// I. Going over all common attributes.
	
	CommonAttributeMetadata = Metadata.CommonAttributes.Find(Separator);
	If CommonAttributeMetadata = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?????????? ???????????????? %1 ???? ?????????????????? ?? ????????????????????????.'; en = 'Common attribute %1 was not found in the configuration.'; pl = 'Wsp??lny rekwizyt %1 nie wykryto w konfiguracji.';es_ES = 'Atributo com??n %1 no se ha encontrado en la configuraci??n.';es_CO = 'Atributo com??n %1 no se ha encontrado en la configuraci??n.';tr = 'Ortak ??znitelik %1 yap??land??rmada bulunamad??.';it = 'Il requisito generale %1 non ?? stato rilevato all''interno della configurazione.';de = 'Die gemeinsamen Requisiten %1 sind in der Konfiguration nicht enthalten.'"), Separator);
	EndIf;
	
	If CommonAttributeMetadata.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
		
		CommonAttributeComposition = CommonAttributeContent(CommonAttributeMetadata.Name);
		
		UseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Use;
		AutoUseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Auto;
		CommonAttributeAutoUse = 
			(CommonAttributeMetadata.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
		
		For Each CompositionItem In CommonAttributeComposition Do
			
			If (CommonAttributeAutoUse AND CompositionItem.Use = AutoUseCommonAttribute)
				OR CompositionItem.Use = UseCommonAttribute Then
				
				AdditionalData = New Structure("Name,Separator,ConditionalSeparation", CompositionItem.Metadata.Name, Separator, Undefined);
				If CompositionItem.ConditionalSeparation <> Undefined Then
					AdditionalData.ConditionalSeparation = CompositionItem.ConditionalSeparation.FullName();
				EndIf;
				
				Result.Insert(CompositionItem.Metadata.FullName(), New FixedStructure(AdditionalData));
				
				// Recalculation separation is determined by the calculation register where it belongs.
				If Common.IsCalculationRegister(CompositionItem.Metadata) Then
					
					Recalculations = CompositionItem.Metadata.Recalculations;
					For Each Recalculation In Recalculations Do
						
						AdditionalData.Name = Recalculation.Name;
						Result.Insert(Recalculation.FullName(), New FixedStructure(AdditionalData));
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?????? ???????????? ?????????????????? %1 ???? ???????????????????????? ???????????????????? ????????????.'; en = 'Data separation is used for the %1 common attribute.'; pl = 'Dla wsp??lnego rekwizytu %1 nie stosuje si?? podzia?? danych.';es_ES = 'Separaci??n de datos %1 no est?? utilizada para el atributo com??n.';es_CO = 'Separaci??n de datos %1 no est?? utilizada para el atributo com??n.';tr = '%1 ortak ??zelli??i i??in veri ay??rma kullan??lm??yor.';it = 'La separazione dei dati non ?? utilizzata per l''attributo generale %1.';de = 'F??r das gemeinsame Requisit %1 wird keine Datentrennung verwendet.'"), Separator);
		
	EndIf;
	
	// II. In case of sequences and document journals, determining whether they are separated by included documents.
	
	// 1) Sequences. Going over sequences and checking the first included document in each of them. If a sequence include no documents it is considered as separated.
	For Each SequenceMetadata In Metadata.Sequences Do
		
		AdditionalData = New Structure("Name,Separator,ConditionalSeparation", SequenceMetadata.Name, Separator, Undefined);
		
		If SequenceMetadata.Documents.Count() = 0 Then
			
			MessageTemplate = NStr("ru = '?? ???????????????????????????????????? %1 ???? ???????????????? ???? ???????????? ??????????????????.'; en = 'The %1 sequence contains no documents.'; pl = 'Sekwencja %1 nie zawiera ??adnych dokument??w.';es_ES = 'Secuencia %1 no incluye ning??n documento.';es_CO = 'Secuencia %1 no incluye ning??n documento.';tr = 'S??ra %1 herhangi bir belge i??ermez.';it = 'La sequenza %1 non contiene alcun documento.';de = 'Die Sequenz %1 enth??lt keine Dokumente.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, SequenceMetadata.Name);
			WriteLogEvent(NStr("ru = '?????????????????? ?????????????????????? ???????????????? ????????????????????'; en = 'Getting separated metadata objects'; pl = 'Odbieraj osobne obiekty metadanych';es_ES = 'Recibir los objetos de metadatos separados';es_CO = 'Recibir los objetos de metadatos separados';tr = 'Ayr?? meta veri nesneleri al';it = 'Ricezione di oggetti di metadati separati';de = 'Empfange separate Metadatenobjekte'", 
				CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, 
				SequenceMetadata, , MessageText);
			
			Result.Insert(SequenceMetadata.FullName(), New FixedStructure(AdditionalData));
			
		Else
			
			For Each DocumentMetadata In SequenceMetadata.Documents Do
				
				AdditionalDataFromDocument = Result.Get(DocumentMetadata.FullName());
				
				If AdditionalDataFromDocument <> Undefined Then
					FillPropertyValues(AdditionalData, AdditionalDataFromDocument, "Separator,ConditionalSeparation");
					Result.Insert(SequenceMetadata.FullName(), New FixedStructure(AdditionalData));
				EndIf;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// 2) Going over sequences and checking the first included document in each of them. If a journal include no documents it is considered as separated.
	For Each DocumentJournalMetadata In Metadata.DocumentJournals Do
		
		AdditionalData = New Structure("Name,Separator,ConditionalSeparation", DocumentJournalMetadata.Name, Separator, Undefined);
		
		If DocumentJournalMetadata.RegisteredDocuments.Count() = 0 Then
			
			MessageTemplate = NStr("ru = '?? ???????????? %1 ???? ???????????????? ???? ???????????? ??????????????????.'; en = 'The %1 journal contains no documents.'; pl = 'Dziennik %1 nie zawiera ??adnych dokument??w.';es_ES = 'Registro %1 no contiene ning??n documento.';es_CO = 'Registro %1 no contiene ning??n documento.';tr = 'G??nl??k%1 herhangi bir belge i??ermiyor.';it = 'Il registro %1 non contiene alcun documento.';de = 'Journal %1 enth??lt keine Dokumente.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, DocumentJournalMetadata.Name);
			WriteLogEvent(NStr("ru = '?????????????????? ?????????????????????? ???????????????? ????????????????????'; en = 'Getting separated metadata objects'; pl = 'Odbieraj osobne obiekty metadanych';es_ES = 'Recibir los objetos de metadatos separados';es_CO = 'Recibir los objetos de metadatos separados';tr = 'Ayr?? meta veri nesneleri al';it = 'Ricezione di oggetti di metadati separati';de = 'Empfange separate Metadatenobjekte'", 
				CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, 
				DocumentJournalMetadata, , MessageText);
			
			Result.Insert(DocumentJournalMetadata.FullName(), New FixedStructure(AdditionalData));
			
		Else
			
			For Each DocumentMetadata In DocumentJournalMetadata.RegisteredDocuments Do
				
				AdditionalDataFromDocument = Result.Get(DocumentMetadata.FullName());
				
				If AdditionalDataFromDocument <> Undefined Then
					FillPropertyValues(AdditionalData, AdditionalDataFromDocument, "Separator,ConditionalSeparation");
					Result.Insert(DocumentJournalMetadata.FullName(), New FixedStructure(AdditionalData));
				EndIf;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion
