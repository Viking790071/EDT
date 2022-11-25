///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Configures multilanguage data settings.
//
// Parameters:
//   Settings - Structure - a subsystem settings collection. Attributes:
//     * AdditionalLanguageCode1 - String - a code of the first default additional language.
//     * AdditionalLanguageCode2 - String - a code of the second default additional language.
//     * MultilanguageData - Boolean - if True, an interface for entering multilanguage data ​​will 
//                                       be added automatically to attributes that support data input in several languages.
//
// Example:
//  Settings.AdditionalLanguageCode1 = "en";
//  Settings.AdditionalLanguageCode2 = "it";
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

#EndRegion
