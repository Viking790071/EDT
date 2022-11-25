#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// SaaSTechnology.ExportImportData

// Returns the catalog attributes that naturally form a catalog item key.
//
// Returns:
//  Array (String) - an array of attribute names that form a natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array;
	Result.Add("Description");
	
	Return Result;
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#Region Private

Function ClosingDatesSectionsProperties() Export
	
	Sections = New ValueTable;
	Sections.Columns.Add("Name",           New TypeDescription("String",,,, New StringQualifiers(150)));
	Sections.Columns.Add("ID", New TypeDescription("UUID"));
	Sections.Columns.Add("Presentation", New TypeDescription("String"));
	Sections.Columns.Add("ObjectsTypes",  New TypeDescription("Array"));
	
	SSLSubsystemsIntegration.OnFillPeriodClosingDatesSections(Sections);
	PeriodClosingDatesOverridable.OnFillPeriodClosingDatesSections(Sections);
	
	ErrorTitle =
		NStr("ru = 'Ошибка в процедуре OnFillPeriodClosingDatesSections
		           |общего модуля PeriodClosingDatesOverridable.'; 
		           |en = 'An error occurred in the OnFillPeriodClosingDatesSections procedure of the 
		           |PeriodClosingDatesOverridable common module.'; 
		           |pl = 'Błąd w procedurze OnFillPeriodClosingDatesSections
		           |wspólnego modułu PeriodClosingDatesOverridable.';
		           |es_ES = 'Error en el procedimiento OnFillPeriodClosingDatesSections
		           |del módulo común PeriodClosingDatesOverridable.';
		           |es_CO = 'Error en el procedimiento OnFillPeriodClosingDatesSections
		           |del módulo común PeriodClosingDatesOverridable.';
		           |tr = 'Prosedür hatası Genel modülün
		           |OnFillPeriodClosingDatesSections PeriodClosingDatesOverridable .';
		           |it = 'Si è verificato un errore nella procedura OnFillPeriodClosingDatesSections del modulo comune 
		           |PeriodClosingDatesOverridable.';
		           |de = 'Fehler in der Prozedur OnFillPeriodClosingDatesSections
		           |des allgemeinen Moduls von PeriodClosingDatesOverridable.'")
		+ Chars.LF
		+ Chars.LF;
	
	ClosingDatesSections     = New Map;
	SectionsWithoutObjects    = New Array;
	AllSectionsWithoutObjects = True;
	
	ClosingDatesObjectsTypes = New Map;
	Types = Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections.Type.Types();
	For Each Type In Types Do
		If Type = Type("EnumRef.PeriodClosingDatesPurposeTypes")
		 Or Type = Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections")
		 Or Not Common.IsReference(Type) Then
			Continue;
		EndIf;
		ClosingDatesObjectsTypes.Insert(Type, True);
	EndDo;
	
	For Each Section In Sections Do
		If Not ValueIsFilled(Section.Name) Then
			Raise ErrorTitle + NStr("ru = 'Имя раздела дат запрета не заполнено.'; en = 'Name for period-end closing date section is not populated.'; pl = 'Nie wypełniono rozdziału dat zakazu.';es_ES = 'El nombre de la división de las fechas de restricción no está rellenado.';es_CO = 'El nombre de la división de las fechas de restricción no está rellenado.';tr = 'Dönem sonu kapanış tarihi için ad doldurulmadı.';it = 'Nome per sezione della data di chiusura della fine periodo non compilato.';de = 'Der Name des Verbotsdatumsbereichs wird nicht ausgefüllt.'");
		EndIf;
		
		If ClosingDatesSections.Get(Section.Name) <> Undefined Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Имя раздела дат запрета ""%1"" уже определено.'; en = 'Name for the ""%1"" period-end closing date section is already determined.'; pl = 'Nazwa rozdziału dat zakazu ""%1"" jest już określona.';es_ES = 'El nombre de la división de las fechas de restricción ""%1"" está predeterminado.';es_CO = 'El nombre de la división de las fechas de restricción ""%1"" está predeterminado.';tr = '""%1"" dönem sonu kapanış tarihi bölümü için ad zaten belirlendi.';it = 'Nome per la sezione della data di chiusura della fine periodo ""%1"" già determinato.';de = 'Der Name des Verbotsdatums ""%1"" wurde bereits definiert.'"),
				Section.Name);
		EndIf;
		
		If Not ValueIsFilled(Section.ID) AND Section.Name <> "SingleDate" Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Идентификатор раздела дат запрета ""%1"" не заполнен.'; en = 'The ""%1""  period-end closing date section ID is required.'; pl = 'Nie wypełniono rozdziału dat zakazu ""%1"".';es_ES = 'El identificador de la división de las fechas de restricción ""%1"" no está rellenado.';es_CO = 'El identificador de la división de las fechas de restricción ""%1"" no está rellenado.';tr = '""%1"" dönem sonu kapanış tarihi bölümü kimliği doldurulmadı.';it = 'L''ID ""%1"" della sezione della data di chiusura di fine periodo è richiesto.';de = 'Die Verbotsdatumskennung ""%1"" wird nicht ausgefüllt.'"),
				Section.Name);
		EndIf;
		
		SectionRef = GetRef(Section.ID);
		
		If ClosingDatesSections.Get(SectionRef) <> Undefined Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Идентификатор ""%1"" раздела дат запрета
				           |""%2"" уже используется для раздела ""%3"".'; 
				           |en = 'ID ""%1"" of the 
				           |""%2"" period-end closing date section is already used for the ""%3"" section.'; 
				           |pl = 'Identyfikator ""%1"" rozdziału dat zakazu
				           |""%2"" jest już używana do rozdziału ""%3"".';
				           |es_ES = 'El identificador ""%1"" de la división de las fechas de restricción
				           |""%2"" ya se usa para dividir ""%3"".';
				           |es_CO = 'El identificador ""%1"" de la división de las fechas de restricción
				           |""%2"" ya se usa para dividir ""%3"".';
				           |tr = '""%2"" dönem sonu kapanış tarihi bölümünün 
				           |""%1"" kimliği ""%3"" bölümü için zaten kullanılıyor.';
				           |it = 'ID ""%1"" della sezione della data di chiusura della fine periodo 
				           |""%2"" già utilizzata per la sezione ""%3"".';
				           |de = 'Die Kennung ""%1"" des Verbotsdatumsabschnitts
				           |""%2"" wird bereits für den Abschnitt ""%3"" verwendet.'"),
				Section.ID, Section.Name, ClosingDatesSections.Get(SectionRef).Name);
		EndIf;
		
		If Not ValueIsFilled(Section.Presentation) Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Представление раздела дат запрета ""%1"" не заполнено.'; en = 'Presentation of the ""%1"" period-end closing date section is not filled in.'; pl = 'Nie wypełniono prezentacji rozdziału dat zakazu ""%1""';es_ES = 'La presentación de la división de las fechas de restricción ""%1"" no está rellenada.';es_CO = 'La presentación de la división de las fechas de restricción ""%1"" no está rellenada.';tr = '""%1"" yasak tarihi bölümünün görünümü doldurulmadı.';it = 'Presentazione della sezione della data di chiusura della fine periodo ""%1"" non compilata.';de = 'Präsentation des Abschnitts Verbotsdatum ""%1"" ist nicht ausgefüllt.'"),
				Section.Name);
		EndIf;
		
		ObjectsTypes = New Array;
		For Each Type In Section.ObjectsTypes Do
			AllSectionsWithoutObjects = False;
			If Not Common.IsReference(Type) Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Тип ""%1"" указан, как тип объектов для раздела дат запрета ""%2"".
					           |Однако это не тип ссылки.'; 
					           |en = 'The ""%1"" type is specified as an object type for the ""%2"" period-end closing date section. 
					           |It is not a reference type.'; 
					           |pl = 'Typ ""%1"" został określony jako typ obiektów dla rozdziału dat zakazu ""%2"".
					           |Jednak nie jest to typ linku.';
					           |es_ES = 'El tipo ""%1"" está indicado como el tipo de objetos para dividir las fechas de restricción ""%2"".
					           |Pero no es el tipo de referencia.';
					           |es_CO = 'El tipo ""%1"" está indicado como el tipo de objetos para dividir las fechas de restricción ""%2"".
					           |Pero no es el tipo de referencia.';
					           |tr = '""%1"" türü, ""%2"" yasak tarihleri bölümü için nesne türü olarak belirlendi.
					           |Ancak bu referans türü değil.';
					           |it = 'Il tipo ""%1"" non è indicato come un tipo di oggetto per la sezione della data di chiusura della fine periodo ""%2"". 
					           |Non è un tipo di riferimento.';
					           |de = 'Als Objekttyp für den Abschnitt ""%1"" für das Verbotsdatum wird der Typ ""%2"" angegeben.
					           |Dies ist jedoch keine Referenzart.'"),
					String(Type), Section.Name);
			EndIf;
			If ClosingDatesObjectsTypes.Get(Type) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Тип объектов ""%1"" раздела дат запрета ""%2""
					           |не указан в свойстве ""Тип"" плана видов характеристик ""Разделы дат запрета изменения"".'; 
					           |en = 'The ""%1"" object type of the ""%2"" 
					           |period-end closing dates section is not specified in the ""Type"" property of the ""Period-end closing dates sections"" chart of characteristic types.'; 
					           |pl = 'Typ obiektów ""%1"" rozdziału dat zakazu ""%2""
					           | nie został określony we właściwości ""Typ"" planu rodzajów charakterystyk ""Rozdziały dat zakazu zmian"".';
					           |es_ES = 'El tipo de los objetos ""%1"" de la división de las fechas de restricción ""%2""
					           |no está indicado en la propiedad ""Tipo"" del plan de los tipos de características ""Divisiones de las fechas de restricción del cambio"".';
					           |es_CO = 'El tipo de los objetos ""%1"" de la división de las fechas de restricción ""%2""
					           |no está indicado en la propiedad ""Tipo"" del plan de los tipos de características ""Divisiones de las fechas de restricción del cambio"".';
					           |tr = '""%1"" yasak tarihleri ""%2"" bölümünün nesne türü 
					           | ""Değişiklik yasağı tarihlerinin bölümleri"" özellik türleri planının ""Tür"" özelliğinde belirtilmedi.';
					           |it = 'Il tipo di oggetto ""%1"" della sezione date chiusura di fine periodo ""%2""
					           | non è indicato nella proprietà ""Tipo"" del piano dei tipi di caratteristiche ""Sezioni date di chiusura di fine periodo"".';
					           |de = 'Der Objekttyp ""%1"" des Verbotsdatumsabschnitts ""%2""
					           |ist in der Eigenschaft ""Typ"" vom Merkmalsplan ""Verbotsdatumsabschnitte ändern"" nicht angegeben.'"),
					String(Type), Section.Name);
			EndIf;
			TypeMetadata = Metadata.FindByType(Type);
			FullName = TypeMetadata.FullName();
			ObjectManager = Common.ObjectManagerByFullName(FullName);
			TypeProperties = New Structure;
			TypeProperties.Insert("EmptyRef",  ObjectManager.EmptyRef());
			TypeProperties.Insert("FullName",     FullName);
			TypeProperties.Insert("Presentation", String(Type));
			ObjectsTypes.Add(New FixedStructure(TypeProperties));
		EndDo;
		
		SectionProperties = New Structure;
		SectionProperties.Insert("Name",           Section.Name);
		SectionProperties.Insert("Ref",        SectionRef);
		SectionProperties.Insert("Presentation", Section.Presentation);
		SectionProperties.Insert("ObjectsTypes",  New FixedArray(ObjectsTypes));
		SectionProperties = New FixedStructure(SectionProperties);
		ClosingDatesSections.Insert(SectionProperties.Name,    SectionProperties);
		ClosingDatesSections.Insert(SectionProperties.Ref, SectionProperties);
		
		If ObjectsTypes.Count() = 0 Then
			SectionsWithoutObjects.Add(Section.Name);
		EndIf;
	EndDo;
	
	// Adding a blank section (a single date).
	SectionProperties = New Structure;
	SectionProperties.Insert("Name", "");
	SectionProperties.Insert("Ref", EmptyRef());
	SectionProperties.Insert("Presentation", NStr("ru = 'Общая дата'; en = 'Common date'; pl = 'Wspólna data';es_ES = 'Fecha común';es_CO = 'Fecha común';tr = 'Ortak tarih';it = 'Data comune';de = 'Gemeinsame Datum'"));
	SectionProperties.Insert("ObjectsTypes",  New FixedArray(New Array));
	SectionProperties = New FixedStructure(SectionProperties);
	ClosingDatesSections.Insert(SectionProperties.Name,    SectionProperties);
	ClosingDatesSections.Insert(SectionProperties.Ref, SectionProperties);
	
	Properties = New Structure;
	Properties.Insert("Sections",               New FixedMap(ClosingDatesSections));
	Properties.Insert("SectionsWithoutObjects",    New FixedArray(SectionsWithoutObjects));
	Properties.Insert("AllSectionsWithoutObjects", AllSectionsWithoutObjects);
	Properties.Insert("NoSectionsAndObjects",  Sections.Count() = 0);
	Properties.Insert("SingleSection",    ?(Sections.Count() = 1,
	                                             ClosingDatesSections[Sections[0].Name].Ref,
	                                             EmptyRef()));
	Properties.Insert("ShowSections",     Properties.AllSectionsWithoutObjects
	                                           Or Not ValueIsFilled(Properties.SingleSection));
	
	Return New FixedStructure(Properties);
	
EndFunction

#EndRegion

#EndIf