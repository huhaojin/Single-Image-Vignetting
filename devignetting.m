function [devig] = devignetting(im)
%devignetting - ȥͼ�����/����
%
% input:
%   - im: h*w, grayͼ��
% output:
%   - devig, h*w, �����ͼ��
%
% docs:
%   - Single-Image Vignetting Correction by Constrained Minimization of log-Intensity Entropy
%

[h, w, ~] = size(im);
im = double(im);
cx = w / 2;
cy = h / 2;

% �������Ų���
A = 0; B = 0; C = 0;
min_entropy = 1000000000000.0;
step = 0.2;
for a = -10:10 % A/B/C���ŵķ�Χ��[-2,2]
    for b = -10:10
        for c = -10:10
            temp_a = a * step;
            temp_b = b * step;
            temp_c = c * step;
            if para_check(temp_a, temp_b, temp_c)
                temp_entropy = calc_log_entropy(im, temp_a, temp_b, temp_c, cx, cy);
                if temp_entropy < min_entropy
                    A = temp_a;
                    B = temp_b;
                    C = temp_c;
                    min_entropy = temp_entropy;
                end
            end
        end
    end
end

% ����
devig = zeros(h, w);
dist_factor = 1 / (cx * cx + cy * cy);
for y = 1:h
    dist_y = (y - cy) * (y - cy);
    for x = 1:w
        dist_x = (x - cx) * (x - cx);
        dist = dist_x + dist_y;
        R2 = dist * dist_factor; % ��ʽ12, R2 = r^2
        gain = 1 + A * R2 + B * R2^2 + C * R2^3; % ��ʽ11, gain=1+a*r^2+b*r^4+c*r^6
        correction = round(gain * im(y,x)); % �������ֵ
        devig(y, x) = correction;
    end
end
devig = uint8(devig);

end

function [entropy] = calc_log_entropy(im, A, B, C, cx, cy)
%calc_log_entropy - ����ͼ�������
%
% input:
%   - im: h*w, grayͼ��
%   - A: float, ����
%   - B: float, ����
%   - C: float, ����
%   - cx: int, ����
%   - cy: int, ����
% output:
%   - entropy: float, ������
%
% docs:
%

[h, w, ~] = size(im);

% log
log_factor = 255.0 / log2(256.0);
im_log = zeros(h, w);
dist_factor = 1 / (cx * cx + cy * cy);
for y = 1:h
    dist_y = (y - cy) * (y - cy);
    for x = 1:w
        dist_x = (x - cx) * (x - cx);
        dist = dist_x + dist_y;
        R2 = dist * dist_factor; % ��ʽ12, R2 = r^2
        gain = 1 + A * R2 + B * R2^2 + C * R2^3; % ��ʽ11, gain=1+a*r^2+b*r^4+c*r^6
        correction = gain * im(y,x); % �������ֵ

        im_log(y,x) = correction;
    end
end
im_log = log_factor * log2(im_log + 1); % ��ʽ6
im_log = max(im_log, 0); % ������[0, 255]
im_log = min(im_log, 255);

% ֱ��ͼ
hist = zeros(256, 1);
for y = 1:h
    for x = 1:w
        val = im_log(y,x) + 1;
        idx_d = floor(val);
        idx_u = ceil(val);
        hist(idx_d) = hist(idx_d) + 1 + idx_d - val; % ��ʽ7
        hist(idx_u) = hist(idx_u) + idx_u - val;
    end
end

% ƽ������, �뾶Ϊ4
temp_hist = zeros(256 + 4*2, 1);
temp_hist(5:256+4) = hist;
temp_hist(1) = hist(5); % �������
temp_hist(2) = hist(4);
temp_hist(3) = hist(3);
temp_hist(4) = hist(2);
temp_hist(261) = hist(255);
temp_hist(262) = hist(254);
temp_hist(263) = hist(253);
temp_hist(264) = hist(252);
for idx = 1:256
    % ��ʽ8
    hist(idx) = temp_hist(idx) ...
                + temp_hist(idx+1)*2 ...
                + temp_hist(idx+2)*3 ...
                + temp_hist(idx+3)*4 ...
                + temp_hist(idx+4)*5 ...
                + temp_hist(idx+5)*4 ...
                + temp_hist(idx+6)*3 ...
                + temp_hist(idx+7)*2 ...
                + temp_hist(idx+8);
end
hist = hist / 25;

% ����ͼ����
entropy = 0;
sum_hist = sum(hist);
for idx = 1:256
    if hist(idx) ~= 0
        pk = hist(idx) / sum_hist;
        entropy = entropy - pk * log2(pk);
    end
end

end

function [checked] = para_check(A, B, C)
% para_check - ����У���Ƿ����, ��ʽ18
%
% input:
%   - A: float, ����
%   - B: float, ����
%   - C: float, ����
% output:
%   - checked: bool, 1-��������; 0-����������
%
% docs:
%

if (1 + A + B + C > 3) % ��ʽ11, r=1ʱ�����������ȵ���
    checked = false;
    return;
end

if C == 0
    if A <= 0 || A + 2*B <= 0 % ��ʽ15, ���C=0, ��r=0ʱ, A>0, ��r=1ʱ, A+2B>0
        checked = false;
        return;
    end
else
    tmp = 4 * B * B - 12 * A * C;
    if C < 0
        if tmp >= 0
            tmp_q = sqrt(tmp);
            q_minus = (-2 * B - tmp_q) / (6 * C); % ��ʽ17
            q_plus  = (-2 * B + tmp_q) / (6 * C);
            if q_minus > 0 || q_plus < 1
                checked = false;
                return;
            end
        else
            checked = false;
            return;
        end
    else
        if tmp >= 0
            tmp_q = sqrt(tmp);
            q_minus = (-2 * B - tmp_q) / (6 * C);
            q_plus  = (-2 * B + tmp_q) / (6 * C);
            if ~((q_minus <= 0 && q_plus <=0) || (q_minus >= 1  && q_plus >= 1))
                checked = false;
                return;
            end
        end
    end
end
checked = true;

end