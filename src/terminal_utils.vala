namespace Verminal {
    public enum PayloadFormat {
        ASCII,
        HEX
    }

    public enum LineEnding {
        NONE,
        LF,
        CR,
        CRLF
    }

    public enum ConnectionKind {
        SERIAL,
        TCP,
        UDP
    }

    public string line_ending_text (LineEnding ending) {
        switch (ending) {
            case LineEnding.LF:
                return "\n";
            case LineEnding.CR:
                return "\r";
            case LineEnding.CRLF:
                return "\r\n";
            default:
                return "";
        }
    }

    public string format_bytes_ascii (uint8[] bytes) {
        var out = new StringBuilder ();
        foreach (uint8 b in bytes) {
            if (b == 0x0a) {
                out.append ("\\n\n");
            } else if (b == 0x0d) {
                out.append ("\\r");
            } else if (b == 0x09) {
                out.append ("\t");
            } else if (b >= 0x20 && b <= 0x7e) {
                out.append_c ((char) b);
            } else {
                out.append ("\\x%02X".printf (b));
            }
        }
        return out.str;
    }

    public string format_bytes_hex (uint8[] bytes) {
        var out = new StringBuilder ();
        for (int i = 0; i < bytes.length; i++) {
            if (i > 0) out.append_c (' ');
            out.append ("%02X".printf (bytes[i]));
        }
        return out.str;
    }

    public string format_bytes (uint8[] bytes, PayloadFormat format) {
        return format == PayloadFormat.HEX ? format_bytes_hex (bytes) : format_bytes_ascii (bytes);
    }

    public bool parse_payload (string text, PayloadFormat format, LineEnding ending, out uint8[] bytes, out string error) {
        var payload = text + line_ending_text (ending);

        if (format == PayloadFormat.ASCII) {
            bytes = payload.data;
            error = "";
            return true;
        }

        var compact = new StringBuilder ();
        for (int i = 0; i < payload.length; i++) {
            char c = payload[i];
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ':' || c == '-' || c == ',') {
                continue;
            }
            if (!c.isxdigit ()) {
                bytes = {};
                error = "HEX payload contains '%c'".printf (c);
                return false;
            }
            compact.append_c (c);
        }

        if (compact.len % 2 != 0) {
            bytes = {};
            error = "HEX payload must contain complete byte pairs";
            return false;
        }

        uint8[] parsed = new uint8[compact.len / 2];
        for (int i = 0; i < parsed.length; i++) {
            parsed[i] = (uint8) ((hex_value (compact.str[i * 2]) << 4) | hex_value (compact.str[i * 2 + 1]));
        }

        bytes = parsed;
        error = "";
        return true;
    }

    private int hex_value (char c) {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return 0;
    }

    public string stamp_now () {
        var now = new DateTime.now_local ();
        return now.format ("%H:%M:%S");
    }
}
