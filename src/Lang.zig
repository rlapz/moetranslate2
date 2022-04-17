// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");

const config = @import("config.zig");
const util = @import("util.zig");
const Url = @import("Url.zig");
const Error = @import("Error.zig").Error;

const Lang = @This();

// zig fmt: off
key  : []const u8,
value: []const u8,

const langs = [_]Lang{
    .{ .key = "auto",  .value = "Automatic"           },

    .{ .key = "af",    .value = "Afrikaans"           },
    .{ .key = "sq",    .value = "Albanian"            },
    .{ .key = "am",    .value = "Amharic"             },
    .{ .key = "ar",    .value = "Arabic"              },
    .{ .key = "hy",    .value = "Armenian"            },
    .{ .key = "az",    .value = "Azerbaijani"         },
    .{ .key = "eu",    .value = "Basque"              },
    .{ .key = "be",    .value = "Belarusian"          },
    .{ .key = "bn",    .value = "Bengali"             },
    .{ .key = "bs",    .value = "Bosnian"             },
    .{ .key = "bg",    .value = "Bulgarian"           },
    .{ .key = "ca",    .value = "Catalan"             },
    .{ .key = "ceb",   .value = "Cebuano"             },
    .{ .key = "zh-CN", .value = "Chinese Simplified"  },
    .{ .key = "zh-TW", .value = "Chinese Traditional" },
    .{ .key = "co",    .value = "Corsican"            },
    .{ .key = "hr",    .value = "Croatian"            },
    .{ .key = "cs",    .value = "Czech"               },
    .{ .key = "da",    .value = "Danish"              },
    .{ .key = "nl",    .value = "Dutch"               },
    .{ .key = "en",    .value = "English"             },
    .{ .key = "eo",    .value = "Esperanto"           },
    .{ .key = "et",    .value = "Estonian"            },
    .{ .key = "fi",    .value = "Finnish"             },
    .{ .key = "fr",    .value = "French"              },
    .{ .key = "fy",    .value = "Frisian"             },
    .{ .key = "gl",    .value = "Galician"            },
    .{ .key = "ka",    .value = "Georgian"            },
    .{ .key = "de",    .value = "German"              },
    .{ .key = "el",    .value = "Greek"               },
    .{ .key = "gu",    .value = "Gujarati"            },
    .{ .key = "ht",    .value = "Haitian Crole"       },
    .{ .key = "ha",    .value = "Hausan"              },
    .{ .key = "haw",   .value = "Hawaiian"            },
    .{ .key = "iw",    .value = "Hebrew"              },
    .{ .key = "hi",    .value = "Hindi"               },
    .{ .key = "hmn",   .value = "Hmong"               },
    .{ .key = "hu",    .value = "Hungarian"           },
    .{ .key = "is",    .value = "Icelandic"           },
    .{ .key = "ig",    .value = "Igbo"                },
    .{ .key = "id",    .value = "Indonesian"          },
    .{ .key = "ga",    .value = "Irish"               },
    .{ .key = "it",    .value = "Italian"             },
    .{ .key = "ja",    .value = "Japanese"            },
    .{ .key = "jw",    .value = "Javanese"            },
    .{ .key = "kn",    .value = "Kannada"             },
    .{ .key = "kk",    .value = "Kazakh"              },
    .{ .key = "km",    .value = "Khmer"               },
    .{ .key = "rw",    .value = "Kinyarwanda"         },
    .{ .key = "ko",    .value = "Korean"              },
    .{ .key = "ku",    .value = "Kurdish"             },
    .{ .key = "ky",    .value = "Kyrgyz"              },
    .{ .key = "lo",    .value = "Lao"                 },
    .{ .key = "la",    .value = "Latin"               },
    .{ .key = "lv",    .value = "Latvian"             },
    .{ .key = "lt",    .value = "Lithunian"           },
    .{ .key = "lb",    .value = "Luxembourgish"       },
    .{ .key = "mk",    .value = "Macedonian"          },
    .{ .key = "mg",    .value = "Malagasy"            },
    .{ .key = "ms",    .value = "Malay"               },
    .{ .key = "ml",    .value = "Malayam"             },
    .{ .key = "mt",    .value = "Maltese"             },
    .{ .key = "mi",    .value = "Maori"               },
    .{ .key = "mr",    .value = "Marathi"             },
    .{ .key = "mn",    .value = "Mongolian"           },
    .{ .key = "my",    .value = "Myanmar"             },
    .{ .key = "ne",    .value = "Nepali"              },
    .{ .key = "no",    .value = "Norwegian"           },
    .{ .key = "ny",    .value = "Nyanja"              },
    .{ .key = "or",    .value = "Odia"                },
    .{ .key = "ps",    .value = "Pashto"              },
    .{ .key = "fa",    .value = "Persian"             },
    .{ .key = "pl",    .value = "Polish"              },
    .{ .key = "pt",    .value = "Portuguese"          },
    .{ .key = "pa",    .value = "Punjabi"             },
    .{ .key = "ro",    .value = "Romanian"            },
    .{ .key = "ru",    .value = "Russian"             },
    .{ .key = "sm",    .value = "Samoan"              },
    .{ .key = "gd",    .value = "Scots Gaelic"        },
    .{ .key = "sr",    .value = "Serbian"             },
    .{ .key = "st",    .value = "Sesotho"             },
    .{ .key = "sn",    .value = "Shona"               },
    .{ .key = "sd",    .value = "Sindhi"              },
    .{ .key = "si",    .value = "Sinhala"             },
    .{ .key = "sk",    .value = "Slovak"              },
    .{ .key = "sl",    .value = "Slovenian"           },
    .{ .key = "so",    .value = "Somali"              },
    .{ .key = "es",    .value = "Spanish"             },
    .{ .key = "su",    .value = "Sundanese"           },
    .{ .key = "sw",    .value = "Swahili"             },
    .{ .key = "sv",    .value = "Swedish"             },
    .{ .key = "tl",    .value = "Tagalog"             },
    .{ .key = "tg",    .value = "Tajik"               },
    .{ .key = "ta",    .value = "Tamil"               },
    .{ .key = "tt",    .value = "Tatar"               },
    .{ .key = "te",    .value = "Telugu"              },
    .{ .key = "th",    .value = "Thai"                },
    .{ .key = "tr",    .value = "Turkish"             },
    .{ .key = "tk",    .value = "Turkmen"             },
    .{ .key = "uk",    .value = "Ukranian"            },
    .{ .key = "ur",    .value = "Urdu"                },
    .{ .key = "ug",    .value = "Uyghur"              },
    .{ .key = "uz",    .value = "Uzbek"               },
    .{ .key = "vi",    .value = "Vietnamese"          },
    .{ .key = "cy",    .value = "Welsh"               },
    .{ .key = "xh",    .value = "Xhosa"               },
    .{ .key = "yi",    .value = "Yiddish"             },
    .{ .key = "yo",    .value = "Yaruba"              },
    .{ .key = "zu",    .value = "Zulu"                },
};
// zig fmt: on

// Will return the reference
pub fn getByKey(key: []const u8) Error!*const Lang {
    inline for (langs) |*val| {
        if (std.ascii.eqlIgnoreCase(val.key, key))
            return val;
    }

    return Error.LangNotFound;
}

// When the desired language cannot be found
// Return "Unknown" string literal instead of null.
pub inline fn getLangStr(key: []const u8) []const u8 {
    const l = getByKey(key) catch {
        return "Unknown";
    };

    return l.value;
}
