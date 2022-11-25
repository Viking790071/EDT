#Region Internal

// Returns a message version description. The return value is passed in InitialVersionDetails and 
// ResultingVersionDetails parameters.
// FindTranslationChains() procedures.
//
// Parameters:
//  Number - string, message version number in the RR.{S|SS}.ZZ.CC format,
//  Package - string, message version namespace.
//
// Returns:
//  Structure(Number, Package).
//
Function GenerateVersionDescription(Number = Undefined, Package = Undefined) Export
	
	Return New Structure("Number, Package", Number, Package);
	
EndFunction // GenerateVersionDetails()

// For internal use.
Function GetMessageInterface(Val Message) Export
	
	InitialMessagePackages = GetMessagePackages(Message);
	RegisteredInterfaces = MessageInterfacesSaaS.GetOutgoingMessageInterfaces();
	
	For Each InitialMessagePackage In InitialMessagePackages Do
		
		MessageInterface = RegisteredInterfaces.Get(InitialMessagePackage);
		If ValueIsFilled(MessageInterface) Then
			
			Return New Structure("Public, Namespace", MessageInterface, InitialMessagePackage);
			
		EndIf;
		
	EndDo;
	
EndFunction

// For internal use.
Function ExecuteTranslation(Val InitialObject, Val InitialVersionDescription, Val ResultingVersionDescription) Export
	
	InterfaceTranslationChain = GetTranslationChain(
			InitialVersionDescription,
			ResultingVersionDescription);
	If InterfaceTranslationChain = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'В конфигурации не зарегистрирован обработчик трансляции из версии %1 в версию %2.'; en = 'Handler of translation from version %1 to version %2 is not registered in the configuration.'; pl = 'W konfiguracji nie jest zarejestrowana procedura przetwarzania przekazania z wersji%1 do wersji%2.';es_ES = 'Manipulador de la traducción de la versión %1 para la versión %2 no se ha registrado en la configuración.';es_CO = 'Manipulador de la traducción de la versión %1 para la versión %2 no se ha registrado en la configuración.';tr = '%2 sürümünden %1 sürümüne çeviri işleyicisi yapılandırmada kayıtlı değil.';it = 'Gestore di traduzioni dalla versione %1 alla versione %2 non è registrato nella configurazione.';de = 'Handler der Übersetzung von Version %1 zu Version %2 ist in der Konfiguration nicht registriert.'"),
			GenerateVersionPresentation(InitialVersionDescription),
			GenerateVersionPresentation(ResultingVersionDescription));
	Else
		
		InterfaceTranslationTable = New ValueTable();
		InterfaceTranslationTable.Columns.Add("Key", New TypeDescription("String"));
		InterfaceTranslationTable.Columns.Add("Value", New TypeDescription("CommonModule"));
		InterfaceTranslationTable.Columns.Add("VersionAsNumber", New TypeDescription("Number"));
		
		For Each InterfaceTranslationStage In InterfaceTranslationChain Do
			
			TableStage = InterfaceTranslationTable.Add();
			FillPropertyValues(TableStage, InterfaceTranslationStage);
			Version = InterfaceTranslationStage.Value.ResultingVersion();
			Digits = StrSplit(Version, ".");
			Iterator = 0;
			VersionAsNumber = 0;
			For Each Digit In Digits Do
				
				VersionAsNumber = VersionAsNumber + (Number(Digit) * Pow(1000, Digits.Count() - Iterator));
				Iterator = Iterator + 1;
				
			EndDo;
			TableStage.VersionAsNumber = VersionAsNumber;
			
		EndDo;
		
		InterfaceTranslationTable.Sort("VersionAsNumber Desc");
		
	EndIf;
	
	For Each InterfaceTranslationStage In InterfaceTranslationTable Do
		
		Handler = InterfaceTranslationStage.Value;
		
		ExecuteStandardProcessing = True;
		Handler.BeforeTranslate(InitialObject, ExecuteStandardProcessing);
		
		If ExecuteStandardProcessing Then
			InterfaceTranslationRules = GenerateInterfaceTranslationRules(InitialObject, InterfaceTranslationStage);
			InitialObject = TranslateObject(InitialObject, InterfaceTranslationRules);
		Else
			InitialObject = Handler.MessageTranslation(InitialObject);
		EndIf;
		
	EndDo;
	
	Return InitialObject;
	
EndFunction

#EndRegion

#Region Private

// Returns a list of packages mentioned in the initial package dependencies.
//
// Parameters:
//  MessageObjectPackage - string, namespace of the package whose dependencies are to be analyzed.
//    
//
// Returns:
//  FixedArray, items - string.
//
Function GetPackageDependencies(Val MessageObjectPackage)
	
	Result = New Array();
	PackageDependencies = XDTOFactory.Packages.Get(MessageObjectPackage).Dependencies;
	For Each Dependence In PackageDependencies Do
		
		MessageDependencyPackage = Dependence.NamespaceURI;
		Result.Add(MessageDependencyPackage);
		NestedDependencies = GetPackageDependencies(MessageDependencyPackage);
		CommonClientServer.SupplementArray(Result, NestedDependencies, True);
		
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Returns a translation handler execution chain to be used for translation between message interface versions.
//  If multiple translation chains applicable for translation between message interface versions are 
//  registered in the configuration, returns a shortest one (with the least number of stages).
//
// Parameters:
//  InitialVersionDetails - Structure, details of initial version of the translated message, 
//      sufficient for unambiguous definition of handlers in the translation table.
//    The structure includes the following fields:
//      Number - string, the initial message version in the RR.{S|SS}.ZZ.CC format,
//      Package - string, namespace of the initial message version,
//  ResultingVersionDetails - Structure, details of resulting version of the translated message, 
//      sufficient for unambiguous definition of handlers in the translation table.
//      
//    The structure includes the following fields:
//      Number - string, resulting message version in the RR.{S|SS}.ZZ.CC format,
//        
//      Package - string, resulting message version namespace.
//        
//
// Returns:
//  FixedMap:
//    Key - Package of resulting message version.
//    Value - CommonModule, translation handler.
//
Function GetTranslationChain(Val InitialVersionDescription, Val ResultingVersionDescription)
	
	RegisteredTranslationHandlers = GetTranslationHandlers();
	
	TranslationChains = New Array();
	FindTranslationChains(
			RegisteredTranslationHandlers,
			InitialVersionDescription,
			ResultingVersionDescription,
			TranslationChains);
	
	If TranslationChains.Count() = 0 Then
		Return Undefined;
	Else
		Return SelectTranslationChain(TranslationChains);
	EndIf;
	
EndFunction

// If multiple message version translation chains are available, returns the shortest chain 
// (containing the least number of stages.
//
// Parameters:
//  TranslationChains - Array, generated by FindTranslationChains() function.
//
// Returns:
//  ValueTable - array item, translation chain containing the least number of stages.
Function SelectTranslationChain(Val TranslationChains)
	
	If TranslationChains.Count() = 1 Then
		Return TranslationChains.Get(0);
	Else
		
		CurrentSelection = Undefined;
		
		For Each TranslationChain In TranslationChains Do
			
			If CurrentSelection = Undefined Then
				CurrentSelection = TranslationChain;
			Else
				CurrentSelection = ?(TranslationChain.Count() < CurrentSelection.Count(),
						TranslationChain, CurrentSelection);
			EndIf;
			
		EndDo;
		
		Return CurrentSelection;
		
	EndIf;
	
EndFunction

// Generates a human-readable presentation for a message interface version.
//
// Parameters:
//  VersionDetails - Structure, GenerateVersionDetails() function execution result.
//
// Returns: string.
//
Function GenerateVersionPresentation(VersionDetails)
	
	Result = "";
	
	If ValueIsFilled(VersionDetails.Number) Then
		
		Result = VersionDetails.Number;
		
	EndIf;
	
	If ValueIsFilled(VersionDetails.Package) Then
		
		PackagePresentation = "{" + VersionDetails.Package + "}";
		
		If Not IsBlankString(Result) Then
			Result = Result + " (" +  PackagePresentation + ")";
		Else
			Result = PackagePresentation;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// For internal use.
Function TranslateObject(Val Object, Val InterfaceTranslationRules)
	
	InitialObjectPackage = Object.Type().NamespaceURI;
	InterfaceTranslationChain = InterfaceTranslationRules.Get(InitialObjectPackage);
	
	If InterfaceTranslationChain = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось определить обработчик трансляции для пакета {%1}, невозможно выполнение стандартной трансляции для обработки данного свойства'; en = 'Cannot define a translation handler for package {%1}, cannot execute the standard translation to process this property'; pl = 'Nie można zdefiniować procedury przetwarzania przekazania dla pakietu {%1}, nie można wykonać standardowego przekazania w celu przetworzenia tej właściwości';es_ES = 'No se puede definir un manipulador de la traducción para el paquete {%1}, no se puede ejecutar la traducción estándar para procesar esta propiedad';es_CO = 'No se puede definir un manipulador de la traducción para el paquete {%1}, no se puede ejecutar la traducción estándar para procesar esta propiedad';tr = '{%1} Paketi için bir çeviri işleyicisi tanımlanamıyor, bu özelliği işlemek için standart çeviriyi yürütemiyor';it = 'Non è possibile definire un gestore di traduzione per il pacchetto {%1}, non può eseguire la traduzione standard per elaborare questa proprietà';de = 'Kann einen Übersetzungshandler für Paket {%1} nicht definieren, kann die Standardübersetzung nicht ausführen, um diese Eigenschaft zu verarbeiten'"), 
			InitialObjectPackage);
	EndIf;
	
	If InterfaceTranslationChain.Count() > 0 Then
		
		For Each TranslationIteration In InterfaceTranslationChain Do
			
			Handler = TranslationIteration.Value;
			
			ExecuteStandardProcessing = True;
			Handler.BeforeTranslate(Object, ExecuteStandardProcessing);
			
			If ExecuteStandardProcessing Then
				Object = StandardProcessing(Object, Handler.ResultingVersionPackage(), InterfaceTranslationRules);
			Else
				Object = Handler.MessageTranslation(Object);
			EndIf;
			
		EndDo;
		
	Else
		
		// When a translation chain contains no iterations, this means that version number was not changed 
		// and you only need to copy property values from the initial object to the resulting object.
		Object = StandardProcessing(Object, Object.Type().NamespaceURI, InterfaceTranslationRules);
		
	EndIf;
	
	Return Object;
	
EndFunction

// For internal use.
Function StandardProcessing(Val Object, Val ResultingObjectPackage, Val InterfaceTranslationRules)
	
	InitialObjectType = Object.Type();
	If InitialObjectType.NamespaceURI = ResultingObjectPackage Then
		ResultingObjectType = InitialObjectType;
	Else
		ResultingObjectType = XDTOFactory.Type(ResultingObjectPackage, InitialObjectType.Name);
		If ResultingObjectType = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось выполнить стандартную обработку трансляции типа %1 в пакет %2: тип %1 не существует в пакете %2.'; en = 'Cannot execute standard translation processing of the %1 type to the %2 package: the %1 type does not exist in the %2 package.'; pl = 'Nie można wykonać standardowego przetwarzania dla tłumaczenia typu %1 na pakiet %2: typ %1 nie istnieje w pakiecie %2.';es_ES = 'No se puede ejecutar el procesamiento de la traducción estándar del tipo %1 al paquete %2: el tipo %1 no existe en el paquete %2.';es_CO = 'No se puede ejecutar el procesamiento de la traducción estándar del tipo %1 al paquete %2: el tipo %1 no existe en el paquete %2.';tr = '%1Paketin %2 türüne standart çeviri işlemi yapılamıyor: %1 pakette %2 tür mevcut değil.';it = 'Impossibile eseguire l''elaborazione di trasmissione standard del tipo %1 al pacchetto %2: Il tipo %1 non esiste nel pacchetto %2.';de = 'Die Standardverarbeitung der Übersetzung vom Typ %1 im Paket %2 konnte nicht ausgeführt werden: Der Typ %1 ist im Paket nicht vorhanden%2.'"),
				"{" + InitialObjectType.NamespaceURI + "}" + InitialObjectType.Name,
				"{" + ResultingObjectPackage + "}");
		EndIf;
	EndIf;
		
	ResultingObject = XDTOFactory.Create(ResultingObjectType);
	InitialObjectProperties = Object.Properties();
	
	For Each Property In ResultingObjectType.Properties Do
		
		OriginalProperty = InitialObjectType.Properties.Get(Property.LocalName);
		If OriginalProperty = Undefined Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось выполнить стандартную обработку конвертации типа %1 в тип %2: свойство %3 не определено для типа %1.'; en = 'Cannot execute standard processing of conversion type %1 to type %2: property %3 is not defined for type %1.'; pl = 'Nie można wykonać standardowego przetwarzania typu %1 konwersji na typ %2: właściwość %3nie jest zdefiniowana dla typu %1.';es_ES = 'No se puede ejecutar el procesamiento estándar del tipo de conversión %1 al tipo %2: la propiedad %3 no está definida para el tipo %1.';es_CO = 'No se puede ejecutar el procesamiento estándar del tipo de conversión %1 al tipo %2: la propiedad %3 no está definida para el tipo %1.';tr = '%1 türün %2 türüne standart dönüşümü yapılamıyor: %3 türü için özellik %1 tanımlanmamıştır.';it = 'non può eseguire elaborazione standard di tipo conversione %1 di tipo %2: proprietà %3 non è definito per tipo %1.';de = 'Die Standardverarbeitung des Konvertierungstyps %1 kann nicht in Typ %2 ausgeführt werden: die Eigenschaft %3 ist für den Typ nicht definiert %1.'"),
				"{" + InitialObjectType.NamespaceURI + "}" + InitialObjectType.Name,
				"{" + ResultingObjectType.NamespaceURI + "}" + ResultingObjectType.Name,
				Property.LocalName);
			
		EndIf;
		
	EndDo;
	
	For Each Property In InitialObjectType.Properties Do
		
		PropertyToTranslate = ResultingObjectType.Properties.Get(Property.LocalName);
		If PropertyToTranslate = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось выполнить стандартную обработку конвертации типа %1 в тип %2: свойство %3 не определено для типа %2.'; en = 'Cannot execute standard processing of conversion type %1 to type %2: property %3 is not defined for type %2.'; pl = 'Nie można wykonać standardowego przetwarzania typu %1 konwersji na typ %2: właściwość %3nie jest zdefiniowana dla typu %2.';es_ES = 'No se puede ejecutar el procesamiento estándar del tipo de conversión %1 al tipo %2: la propiedad %3 no está definida para el tipo %2.';es_CO = 'No se puede ejecutar el procesamiento estándar del tipo de conversión %1 al tipo %2: la propiedad %3 no está definida para el tipo %2.';tr = '%1 türün %2 türüne standart dönüşümü yapılamıyor: %3 türü için özellik %2 tanımlanmamıştır.';it = 'non può eseguire elaborazione standard di tipo conversione %1 di tipo %2: proprietà %3 non è definito per tipo %2.';de = 'Die Standardverarbeitung des Konvertierungstyps %1 kann nicht in Typ %2 ausgeführt werden: Eigenschaft %3 ist für den Typ nicht definiert %2.'"),
				"{" + InitialObjectType.NamespaceURI + "}" + InitialObjectType.Name,
				"{" + ResultingObjectType.NamespaceURI + "}" + ResultingObjectType.Name,
				Property.LocalName);
		EndIf;
			
		If Object.IsSet(Property) Then
			
			If Property.UpperBound = 1 Then
				
				// XDTODataObject or XDTODataValue.
				ValueToTranslate = Object.GetXDTO(Property);
				
				If TypeOf(ValueToTranslate) = Type("XDTODataObject") Then
					ResultingObject.Set(PropertyToTranslate, TranslateObject(ValueToTranslate, InterfaceTranslationRules));
				Else
					ResultingObject.Set(PropertyToTranslate, ValueToTranslate);
				EndIf;
				
			Else
				
				// XDTOList
				ListToTranslate = Object.GetList(Property);
				
				For Iterator = 0 To ListToTranslate.Count() - 1 Do
					
					ListItem = ListToTranslate.GetXDTO(Iterator);
					
					If TypeOf(ListItem) = Type("XDTODataObject") Then
						ResultingObject[Property.LocalName].Add(TranslateObject(ListItem, InterfaceTranslationRules));
					Else
						ResultingObject[Property.LocalName].Add(ListItem);
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return ResultingObject;
	
EndFunction

// For internal use.
Function GenerateInterfaceTranslationRules(Val Message, Val InterfaceTranslationIteration)
	
	InterfaceTranslationRules = New Map();
	
	InitialMessagePackages = New Array();
	ResultingMessagePackages = New Array();
	
	InitialMessagePackages = GetMessagePackages(Message);
	
	InterfaceTranslationHandler = InterfaceTranslationIteration.Value;
	
	ResultingMessagePackages.Add(InterfaceTranslationHandler.ResultingVersionPackage());
	CorrespondentPackageDependencies = GetPackageDependencies(InterfaceTranslationHandler.ResultingVersionPackage());
	CommonClientServer.SupplementArray(ResultingMessagePackages, CorrespondentPackageDependencies, True);
	
	InterfaceTranslationRule = New Map();
	InterfaceTranslationRule.Insert(InterfaceTranslationIteration.Key, InterfaceTranslationIteration.Value);
	
	InterfaceTranslationRules.Insert(InterfaceTranslationHandler.SourceVersionPackage(), InterfaceTranslationRule);
	
	For Each InitialMessagePackage In InitialMessagePackages Do
		
		TranslationChain = InterfaceTranslationRules.Get(InitialMessagePackage);
		
		If TranslationChain = Undefined Then
			
			If ResultingMessagePackages.Find(InitialMessagePackage) <> Undefined Then
				
				// Both the initial and the resulting interface versions use the same package.
				// Instead of translating it, you only need to copy the property values.
				InterfaceTranslationRules.Insert(InitialMessagePackage, New Map());
				
			Else
				
				// The package is used in the initial message interface version but not in the resulting one.
				// It is necessary to determine a resulting version package to which the initial version package must be translated.
				
				AvailableChains = New Array();
				For Each ResultingMessagePackage In ResultingMessagePackages Do
					
					PackageChain = GetTranslationChain(
						GenerateVersionDescription(
								, InitialMessagePackage),
						GenerateVersionDescription(
								, ResultingMessagePackage));
						
					If ValueIsFilled(PackageChain) Then
						 AvailableChains.Add(PackageChain);
					EndIf;
					
				EndDo;
				
				If AvailableChains.Count() > 0 Then
					
					ChainUsed = SelectTranslationChain(AvailableChains);
					InterfaceTranslationRules.Insert(InitialMessagePackage, ChainUsed);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return InterfaceTranslationRules;
	
EndFunction

// Returns an array filled with namespaces used in the message.
//
// Parameters:
//  Message - XDTODataObject, a message whose namespace list is requested.
//    
//
// Returns:
//  Array containing a set of strings.
//
Function GetMessagePackages(Val Message)
	
	Result = New Array();
	
	// XDTO object package
	MessageObjectPackage = Message.Type().NamespaceURI;
	Result.Add(MessageObjectPackage);
	
	// XDTO object package dependencies.
	Dependencies = GetPackageDependencies(MessageObjectPackage);
	CommonClientServer.SupplementArray(Result, Dependencies, True);
	
	// XDTO object properties
	ObjectProperties = Message.Properties();
	For Each Property In ObjectProperties Do
		
		If Message.IsSet(Property) Then
			
			If Property.UpperBound = 1 Then
				
				PropertyValue = Message.GetXDTO(Property);
				
				If TypeOf(PropertyValue) = Type("XDTODataObject") Then
				
					PropertyPackages = GetMessagePackages(PropertyValue);
					CommonClientServer.SupplementArray(Result, PropertyPackages, True);
					
				EndIf;
				
			Else
				
				PropertiesList = Message.GetList(Property);
				Iterator = 0;
				
				For Iterator = 0 To PropertiesList.Count() - 1 Do
					
					ListItem = PropertiesList.GetXDTO(Iterator);
					
					If TypeOf(ListItem) = Type("XDTODataObject") Then
						
						PropertyPackages = GetMessagePackages(ListItem);
						CommonClientServer.SupplementArray(Result, PropertyPackages, True);
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// This procedure is used to generate translation handler execution chains required for message 
// version translation.
//
// Parameters:
//  TranslationHandlers - ValueTable whose structure was generated by 
//      GenerateTranslationHandlerTable() function, containing all message translation handlers 
//      registered in the configuration,
//  InitialVersionDetails - Structure, details of initial version of the translated message, 
//      sufficient for unambiguous definition of handlers in the translation table.
//    The structure includes the following fields:
//      Number - string, the initial message version in the RR.{S|SS}.ZZ.CC format,
//      Package - string, namespace of the initial message version,
//  ResultingVersionDetails - Structure, details of resulting version of the translated message, 
//      sufficient for unambiguous definition of handlers in the translation table.
//      
//    The structure includes the following fields:
//      Number - string, resulting message version in the RR.{S|SS}.ZZ.CC format,
//        
//      Package - string, resulting message version namespace,
//        
//  TranslationChains - Array, once the procedure is completed, this parameter contains all 
//      translation chains available for message translation from the initial version to the resulting version. 
//      The array contains a set of fixed pairs (key - namespace of the resulting version package, 
//      value - CommonModule used as translation handler),
//  CurrentChain - internal parameter used for recursive procedure execution, must not be set during 
//    the initial call.
//
Procedure FindTranslationChains(Val TranslationHandlers, Val InitialVersionDescription, 
			Val ResultingVersionDescription, TranslationChains, CurrentChain = Undefined)
	
	Filter = New Structure();
	If ValueIsFilled(InitialVersionDescription.Number) Then
		Filter.Insert("SourceVersion", InitialVersionDescription.Number);
	EndIf;
	If ValueIsFilled(InitialVersionDescription.Package) Then
		Filter.Insert("SourceVersionPackage", InitialVersionDescription.Package);
	EndIf;
	
	Branches = TranslationHandlers.Copy(Filter);
	For Each Branch In Branches Do
		
		If CurrentChain = Undefined Then
			CurrentChain = New Map();
		EndIf;
		CurrentChain.Insert(Branch.ResultingVersionPackage, Branch.Handler);
		
		If Branch.ResultingVersion = ResultingVersionDescription.Number
				OR Branch.ResultingVersionPackage = ResultingVersionDescription.Package Then
			TranslationChains.Add(New FixedMap(CurrentChain));
		Else
			FindTranslationChains(TranslationHandlers,
					GenerateVersionDescription(
							, Branch.ResultingVersionPackage),
					GenerateVersionDescription(
							ResultingVersionDescription.Number, ResultingVersionDescription.Package),
					TranslationChains, CurrentChain);
		EndIf;
			
	EndDo;
	
EndProcedure

// Translation handler table constructor.
Function CreateTranslationHandlerTable()
	
	Result = New ValueTable();
	Result.Columns.Add("SourceVersion");
	Result.Columns.Add("SourceVersionPackage");
	Result.Columns.Add("ResultingVersion");
	Result.Columns.Add("ResultingVersionPackage");
	Result.Columns.Add("Handler");
	
	Return Result;
	
EndFunction

// Returns a table of message translation handlers registered in the application.
//
Function GetTranslationHandlers()
	
	Result = CreateTranslationHandlerTable();
	TranslationHandlerArray = New Array();
	
	MessageTranslationHandlers = MessageInterfacesSaaS.GetMessageTranslationHandlers();
	CommonClientServer.SupplementArray(TranslationHandlerArray, MessageTranslationHandlers);
	
	XDTOTranslationOverridable.FillMessageTranslationHandlers(TranslationHandlerArray);
	
	For Each Handler In TranslationHandlerArray Do
		
		HandlerRegistration = Result.Add();
		HandlerRegistration.SourceVersion = Handler.SourceVersion();
		HandlerRegistration.ResultingVersion = Handler.ResultingVersion();
		HandlerRegistration.SourceVersionPackage = Handler.SourceVersionPackage();
		HandlerRegistration.ResultingVersionPackage = Handler.ResultingVersionPackage();
		HandlerRegistration.Handler = Handler;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
